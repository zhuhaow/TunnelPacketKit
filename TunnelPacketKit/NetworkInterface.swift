//
//  NetworkInterface.swift
//  TunnelPacketKit
//
//  Created by Zhuhao Wang on 16/1/17.
//  Copyright © 2016年 Zhuhao Wang. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift

protocol NetworkInterfaceDelegate: class {
    func acceptedNewTunnel(_: Tunnel)
    func sendPackets(_: [IPPacket])
}

class NetworkInterface {
    let queue: dispatch_queue_t
    let slowTimer: dispatch_source_t
    let fastTimer: dispatch_source_t
    let tunnelManager: TunnelManager
    weak var delegate: NetworkInterfaceDelegate?
    
    init() {
        DDLogVerbose("Start initialize virtual network interface.")
        
        queue = dispatch_queue_create("TunnelPacketKit.ProcessQueue", DISPATCH_QUEUE_SERIAL)
        slowTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue)
        fastTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue)
        DDLogDebug("Process queue and timer created.")
        
        tunnelManager = TunnelManager()
        tunnelManager.newTunnelHandler = {
            [weak self] tunnel in
            self?.acceptedNewTunnel(tunnel)
        }
        tunnelManager.sendPackets = {
            [weak self] packets in
            self?.sendPackets(packets)
        }
        DDLogDebug("Tunnel manager created.")
        
        DDLogDebug("Start fast and slow timer.")
        dispatch_source_set_timer(slowTimer, DISPATCH_TIME_NOW , Options.slowTimerInterval * NSEC_PER_MSEC, Options.timerLeeway * NSEC_PER_MSEC)
        dispatch_source_set_event_handler(slowTimer) {
            [weak self] in
            self?.slowTimerHandler()
        }
        dispatch_source_set_timer(fastTimer, DISPATCH_TIME_NOW , Options.fastTimerInterval * NSEC_PER_MSEC, Options.timerLeeway * NSEC_PER_MSEC)
        dispatch_source_set_event_handler(fastTimer) {
            [weak self] in
            self?.fastTimerHandler()
        }
        dispatch_resume(slowTimer)
        dispatch_resume(fastTimer)
        DDLogDebug("Timer started.")
        
        DDLogVerbose("Successfully initialized virtual network interface.")
    }
    
    func perform(block: () -> ()) {
        dispatch_async(queue, block)
    }
    
    private func receivedPacket(packet: NSData, version: NSNumber) {
        self.tunnelManager.receivedPacket(packet, version: version)
    }
    
    func receivedPackets(packets: [NSData], versions: [NSNumber]) {
        DDLogDebug("Virtual network interface recieved \(packets.count) packets. Processing them now.")
        perform {
            for var i = 0; i < packets.count; ++i {
                self.receivedPacket(packets[i], version: versions[i])
            }
        }
    }
    
    func acceptedNewTunnel(tunnel: Tunnel) {
        delegate?.acceptedNewTunnel(tunnel)
    }
    
    func sendPackets(packets: [IPPacket]) {
        delegate?.sendPackets(packets)
    }
    
    func slowTimerHandler() {
        DDLogDebug("Slow timer triggered.")
        tunnelManager.slowTimerHandler()
    }
    
    func fastTimerHandler() {
        DDLogDebug("Fast timer triggered.")
        tunnelManager.fastTimerHandler()
    }
}
