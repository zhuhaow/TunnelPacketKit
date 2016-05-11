//
//  SNWUDPTunnel.swift
//  TunnelPacketKit
//
//  Created by Zhuhao Wang on 2/25/16.
//  Copyright © 2016 Zhuhao Wang. All rights reserved.
//

import Foundation
import NetworkExtension
import CocoaLumberjackSwift

@objc protocol SNWUDPTunnelDelegate {
    func ready(_: SNWUDPTunnel)
    func receivedDatagrams(_: [NSData])
    func closed(_: SNWUDPTunnel)
}

class SNWUDPTunnel : NSObject {
    let session: NWUDPSession
    private weak var delegate: SNWUDPTunnelDelegate?
    var lastError: NSError?
    let maxReadDatagrams = 100
    private var dataQueue = [NSData]()
    private let dataProcessQueue = dispatch_queue_create("SNWUDPTunnel.dataProcessingQueue", DISPATCH_QUEUE_SERIAL)
    
    
    init(session: NWUDPSession, delegate: SNWUDPTunnelDelegate?) {
        self.session = session
        self.delegate = delegate
        super.init()
        
        self.session.setReadHandler(readHandler, maxDatagrams: maxReadDatagrams)
        self.session.addObserver(self, forKeyPath: "state", options: .Initial, context: nil)
    }
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        guard keyPath == "state" else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
            return
        }
        
        DDLogVerbose("SNWTunnel state changed to \(session.state).")
        
        switch session.state {
        case .Ready:
            delegate?.ready(self)
        case .Failed:
            closeTunnel()
        case .Cancelled:
            session.removeObserver(self, forKeyPath: "state")
            delegate?.closed(self)
        default:
            break
        }
    }
    
    func readHandler(datagrams: [NSData]?, error: NSError?) {
        guard error == nil else {
            closeTunnelWithError(error)
            return
        }
        
        delegate?.receivedDatagrams(datagrams!)
    }
    
    func sendDatagrams(datagrams: [NSData]) {
        dispatch_async(dataProcessQueue) {
            self.dataQueue.appendContentsOf(datagrams)
            self.writeData()
        }
    }
    
    private func writeData() {
        dispatch_async(dataProcessQueue) {
            self.session.writeMultipleDatagrams(self.dataQueue) {
                error in
                guard error == nil else {
                    self.closeTunnelWithError(error)
                    return
                }
            }
            self.dataQueue.removeAll(keepCapacity: true)
        }
    }
    
    func closeTunnel() {
        session.cancel()
    }
    
    func closeTunnelWithError(error: NSError?) {
        lastError = error
        closeTunnel()
    }
}