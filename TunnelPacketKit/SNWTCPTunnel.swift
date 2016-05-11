//
//  SNWTCPTunnel.swift
//  TunnelPacketKit
//
//  Created by Zhuhao Wang on 2/24/16.
//  Copyright © 2016 Zhuhao Wang. All rights reserved.
//

import Foundation
import NetworkExtension
import CocoaLumberjackSwift

@objc protocol SNWTCPTunnelDelegate : class {
    func connectionEstablished(_: SNWTCPTunnel)
    func connectionClosed(_: SNWTCPTunnel)
    func receivedData(_: NSData, fromTunnel: SNWTCPTunnel)
    optional func dataSend(_: NSData, fromTunnel: SNWTCPTunnel)
    optional func readClosed(_: SNWTCPTunnel)
}

class SNWTCPTunnel : NSObject {
    let connection: NWTCPConnection
    private weak var delegate: SNWTCPTunnelDelegate?
    var lastError: NSError?
    private var dataQueue = Queue<NSData>()
    private var writingData = false
    private let dataProcessQueue = dispatch_queue_create("SNWTCPTunnel.dataProcessingQueue", DISPATCH_QUEUE_SERIAL)
    
    init(connection: NWTCPConnection, delegate: SNWTCPTunnelDelegate?) {
        self.connection = connection
        self.delegate = delegate
        super.init()
        
        self.connection.addObserver(self, forKeyPath: "state", options: .Initial, context: nil)
    }
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        guard keyPath == "state" else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
            return
        }
        
        DDLogVerbose("SNWTunnel state changed to \(connection.state).")
        
        switch connection.state {
        case .Connected:
            delegate?.connectionEstablished(self)
        case .Disconnected:
            closeTunnel()
        case .Cancelled:
            connection.removeObserver(self, forKeyPath: "state")
            delegate?.connectionClosed(self)
        default:
            break
        }
    }
    
    func sendData(data: NSData) {
        dispatch_async(dataProcessQueue) {
            self.dataQueue.enqueue(data)
            self.writeData()
        }
    }
    
    private func writeData() {
        dispatch_async(dataProcessQueue) {
            if !self.writingData {
                if let data = self.dataQueue.dequeue() {
                    self.writingData = true
                    self.connection.write(data) { error in
                        guard error == nil else {
                            self.closeTunnelWithError(error)
                            return
                        }
                        
                        self.delegate?.dataSend?(data, fromTunnel: self)
                        self.writingData = false
                        self.writeData()
                    }
                }
            }
        }
    }
    
    func writeClose() {
        connection.writeClose()
    }
    
    func closeTunnel() {
        connection.cancel()
    }
    
    func closeTunnelWithError(error: NSError?) {
        lastError = error
        closeTunnel()
    }
    
    func readData() {
        connection.readMinimumLength(0, maximumLength: 0) { data, error in
            if let error = error {
                DDLogError("SNWTunnel got an error when reading data: \(error)")
                self.closeTunnelWithError(error)
                return
            }
            
            guard let data = data else {
                self.delegate?.readClosed?(self)
                return
            }
            
            self.delegate?.receivedData(data, fromTunnel: self)
            self.readData()
        }
    }
}