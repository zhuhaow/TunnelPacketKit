//
//  IPAddress.swift
//  TunnelPacketKit
//
//  Created by Zhuhao Wang on 16/1/16.
//  Copyright © 2016年 Zhuhao Wang. All rights reserved.
//

import Foundation

class IPAddress: CustomStringConvertible {
    // this should not return 32 bit value
    func toNetworkEndian() -> UInt32 {
        return 0
    }

    func equalTo(address: IPAddress) -> Bool {
        return false
    }

    var description: String {
        return "IP address"
    }
}

class IPv4Address: IPAddress {
    let intRepresentation: UInt32
    override var description: String {
        return "IPv4 address: \(intRepresentation >> 24).\(intRepresentation >> 16 & 0xFF).\(intRepresentation >> 8 & 0xFF).\(intRepresentation & 0xFF)"
    }

    init(fromInt: UInt32) {
        intRepresentation = fromInt
    }

    convenience init(_ a: Int, _ b: Int, _ c: Int, _ d: Int) {
        self.init(fromInt: UInt32(a << 24 + b << 16 + c << 8 + d))
    }

    override func toNetworkEndian() -> UInt32 {
        return CFSwapInt32HostToBig(intRepresentation)
    }

    override func equalTo(address: IPAddress) -> Bool {
        if let address = address as? IPv4Address {
            return address.intRepresentation == intRepresentation
        }
        return false
    }
}

class IPv6Address: IPAddress {
}
