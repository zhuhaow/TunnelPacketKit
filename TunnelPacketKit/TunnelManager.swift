//
//  TunnelManager.swift
//  TunnelPacketKit
//
//  Created by Zhuhao Wang on 16/1/17.
//  Copyright © 2016年 Zhuhao Wang. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift

class TunnelManager {
    var tunnels = [Tunnel]()
    var newTunnelHandler: (Tunnel -> ())?
    var sendPackets: ([IPPacket] -> ())?
    
    func receivedPacket(rawData: NSData, version: NSNumber) {
        let packet = IPPacket(rawData)
        guard packet.parsePacket() else {
            DDLogError("Failed to parse recieved packet.")
            return
        }
        
        guard packet.version.rawValue == version.unsignedCharValue else {
            DDLogError("Accepted packet with unmatched IP version, system reported \(version) while packet version is \(packet.version)")
            return
        }
        
        // TODO: check for broadcast/multicast address?
        
        guard let tunnel = findOrCreateTunnel(packet) else {
            return
        }
        tunnel.handleIPPacket(packet)
    }
    
    func findTunnel(packet: IPPacket) -> Tunnel? {
        for tunnel in tunnels {
            if tunnel.match(packet) {
                return tunnel
            }
        }
        return nil
    }
    
    func findOrCreateTunnel(packet: IPPacket) -> Tunnel? {
        if let tunnel = findTunnel(packet) {
            return tunnel
        } else {
            if let tunnel = Tunnel.createFromPacket(packet, withManager: self) {
                DDLogVerbose("Created new tunnel: \(tunnel)")
                newTunnelHandler?(tunnel)
                tunnels.append(tunnel)
                return tunnel
            } else {
                DDLogError("Eh, received some packet out of nowhere.")
                // TODO: send RST packet
                return nil
            }
        }
    }
    
    func tunnelClosed(tunnel: Tunnel) {
        guard let index = tunnels.indexOf({$0 === tunnel}) else {
            DDLogError("Got closed signal from an unknown Tunnel.")
            return
        }
        tunnels.removeAtIndex(index)
        DDLogDebug("Tunnel \(tunnel) closed, removed from tunnel manager.")
    }
    
    func slowTimerHandler() {
        for tunnel in tunnels {
            tunnel.slowTimerHandler()
        }
    }
    
    func fastTimerHandler() {
        for tunnel in tunnels {
            tunnel.fastTimerHandler()
        }
    }
}
