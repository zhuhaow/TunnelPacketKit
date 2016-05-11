//
//  ProtocolPacket.swift
//  TunnelPacketKit
//
//  Created by Zhuhao Wang on 16/1/17.
//  Copyright © 2016年 Zhuhao Wang. All rights reserved.
//

import Foundation

/// Base class for TCP and UDP packet.
/// - note: Since it not possible to send out packet other than TCP and UDP, the protocol packet must have port information.
class ProtocolPacket: Packet {
    var sourcePort: UInt16!
    var destinationPort: UInt16!
    var dataOffsetInDatagram: Int { return payloadOffset }
}
