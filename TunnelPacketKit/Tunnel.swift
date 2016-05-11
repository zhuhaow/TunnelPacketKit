//
//  Tunnel.swift
//  TunnelPacketKit
//
//  Created by Zhuhao Wang on 16/1/17.
//  Copyright © 2016年 Zhuhao Wang. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift

protocol TunnelDelegateProtocol: class {
    func tunnelEstablished(_: Tunnel)
    func receivedData(_: NSData, from: Tunnel)
    func remoteClosed(_: Tunnel)
    func closed(_: Tunnel)
    func reset(_: Tunnel)
}

class Tunnel {
    let type: PacketType
    let localIP: IPAddress
    let localPort: UInt16
    let remoteIP: IPAddress
    let remotePort: UInt16
    weak var manager: TunnelManager?

    weak var delegate: TunnelDelegateProtocol?

    init?(fromIPPacket packet: IPPacket, withManager manager: TunnelManager? = nil) {
        type = packet.packetType
        localIP = packet.sourceAddress
        localPort = packet.sourcePort
        remoteIP = packet.destinationAddress
        remotePort = packet.destinationPort
        self.manager = manager
    }

    class func createFromPacket(packet: IPPacket, withManager manager: TunnelManager) -> Tunnel? {
        switch packet.packetType {
        case .TCP:
            return TCPTunnel(fromIPPacket: packet, withManager: manager)
        default:
            DDLogError("Can't create tunnel for packet type \(packet.packetType) yet!")
            return Tunnel(fromIPPacket: packet)
        }
    }

    func match(packet: IPPacket) -> Bool {
        if type == packet.packetType  &&
            localIP.equalTo(packet.sourceAddress) &&
            localPort == packet.sourcePort &&
            remoteIP.equalTo(packet.destinationAddress) &&
            remotePort == packet.destinationPort {
                return true
        } else {
            return false
        }
    }

    /**
     This should be called by `TunnelManager`.
     - warning: Make sure this is called in the process queue.
     
     - parameter packet: the packet to be processed.
     */
    func handleIPPacket(packet: IPPacket) {}

    /**
     Close current tunnel.
     */
    func close() {
        manager?.tunnelClosed(self)
    }
    
    func slowTimerHandler() {}
    
    func fastTimerHandler() {}
    
    internal func sendPackets(packet: [IPPacket]) {
        manager?.sendPackets?(packet)
    }
    
    func sendData(data: NSData) {}
}
