//
//  IPPacket.swift
//  TunnelPacketKit
//
//  Created by Zhuhao Wang on 16/1/16.
//  Copyright © 2016年 Zhuhao Wang. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift

protocol OrderedPacket {
    var startSequence: UInt32 { get }
    /// The last sequence number of the current packet (excluded).
    var endSequence: UInt32 { get }
}

class IPPacket: Packet, OrderedPacket {
    /// The version of the current IP packet.
    var version: IPVersion = .IPv4
    /// The length of the IP packet header.
    var headerLength: UInt8 = 20
    /// This contains the DSCP and ECN of the IP packet. Since we can not send custom IP packet on iOS/OSX, this is useless and simply ignored.
    var ToS: UInt8 = 0
    /// This should be the length of the datagram which should be the length of the payload.
    /// This value is not read from header since NEPacketTunnelFlow has already taken care of it for us.
    var totalLength: UInt16 {
        get {
            // payloadOffset should always be 0
            return UInt16(payloadLength - payloadOffset)
        }
    }

    /// Identification of the current packet. Since we do not support fragment, this is ignored and always will be zero.
    /// - note: Theoratically, this should be a sequentially increasing number. It probably will be implemented.
    var identification: UInt16 = 0
    /// Offset of the current packet. Since we do not support fragment, this is ignored and always will be zero.
    var offset: UInt16 = 0

    var TTL: UInt8 = 64
    var packetType: PacketType = .TCP
    var sourceAddress: IPAddress!
    var destinationAddress: IPAddress!
    var protocolPacket: ProtocolPacket!

    /// Short hand for the contained TCP packet.
    var tcpPacket: TCPPacket? {
        return protocolPacket as? TCPPacket
    }

    var startSequence: UInt32 {
        if let tcpPacket = tcpPacket {
            return tcpPacket.sequenceNumber
        } else {
            return 0
        }
    }

    var endSequence: UInt32 {
        if let tcpPacket = tcpPacket {
            return tcpPacket.endSequence
        } else {
            return 0
        }
    }

    var sourcePort: UInt16 {
        get {
            return protocolPacket.sourcePort
        }
        set {
            protocolPacket.sourcePort = newValue
        }
    }

    var destinationPort: UInt16 {
        get {
            return protocolPacket.destinationPort
        }
        set {
            protocolPacket.destinationPort = newValue
        }
    }

    override func parsePacket() -> Bool {
        guard validate() else {
            DDLogWarn("Received invalid IP packet which should never happen.")
            return false
        }

        let scanner = BinaryDataScanner(data: datagram!, littleEndian: false)
        scanner.skipTo(payloadOffset)

        let vhl = scanner.readByte()!
        guard let v = IPVersion(rawValue: vhl >> 4) else {
            DDLogError("Got unknown ip packet version \(vhl >> 4)")
            return false
        }
        version = v
        headerLength = vhl & 0x0F * 4
        if headerLength != 20 {
            DDLogDebug("Received an IP packet with option, which is not supported yet. The option is ignored.")
        }

        ToS = scanner.readByte()!

        guard totalLength == scanner.read16()! else {
            DDLogError("Packet length mismatches from header.")
            return false
        }

        identification = scanner.read16()!
        offset = scanner.read16()!
        TTL = scanner.readByte()!

        guard let proto = PacketType(rawValue: scanner.readByte()!) else {
            DDLogWarn("Get unsupported packet protocol.")
            return false
        }
        packetType = proto

        // ignore checksum
        _ = scanner.read16()!

        switch version {
        case .IPv4:
            sourceAddress = IPv4Address(fromInt: scanner.read32()!)
            destinationAddress = IPv4Address(fromInt: scanner.read32()!)
        default:
            // IPv6 is not supported yet.
            return false
        }

        switch packetType {
        case .TCP:
            protocolPacket = TCPPacket(datagram, andOffset: Int(headerLength))
        default:
            DDLogError("Can not parse packet header of type \(packetType) yet")
            return false
        }

        return protocolPacket.parsePacket()
    }

    override func buildPacket() -> Bool {
        guard super.buildPacket() else {
            return false
        }

        protocolPacket.setDatagram(datagram!, withOffset: Int(headerLength) + payloadOffset)

        // set header
        setPayloadWithUInt8(headerLength / 4 + version.rawValue << 4, at: 0)
        setPayloadWithUInt8(ToS, at: 1)
        setPayloadWithUInt16(totalLength, at: 2)
        setPayloadWithUInt16(identification, at: 4)
        setPayloadWithUInt16(offset, at: 6)
        setPayloadWithUInt8(TTL, at: 8)
        setPayloadWithUInt8(packetType.rawValue, at: 9)
        // clear checksum bytes
        resetPayloadAt(10, length: 2)
        setPayloadWithUInt32(sourceAddress.toNetworkEndian(), at: 12, swap: false)
        setPayloadWithUInt32(destinationAddress.toNetworkEndian(), at: 16, swap: false)

        // let TCP or UDP packet build
        return protocolPacket.buildPacket()
    }

    func computePseudoHeaderChecksum() -> UInt32 {
        var result: UInt32 = 0
        if let address = sourceAddress as? IPv4Address {
            result += address.intRepresentation >> 16 + address.intRepresentation & 0xFFFF
        }
        if let address = destinationAddress as? IPv4Address {
            result += address.intRepresentation >> 16 + address.intRepresentation & 0xFFFF
        }
        result += UInt32(packetType.rawValue)
        result += UInt32(protocolPacket.payloadLength)
        return result
    }

    override func setChecksum(withPseudoHeaderChecksum: UInt32 = 0) {
        protocolPacket.setChecksum(computePseudoHeaderChecksum())
        setPayloadWithUInt16(Checksum.computeChecksum(datagram!, from: payloadOffset, to: Int(headerLength) + payloadOffset, withPseudoHeaderChecksum: 0), at: 10, swap: false)
    }

    override internal func computePacketLength() -> Int {
        return protocolPacket.computePacketLength() + Int(headerLength)
    }

    override func validate() -> Bool {
        return Checksum.validateChecksum(datagram!, from: payloadOffset, to: Int(headerLength) + payloadOffset)
    }
    
    override func maxDataLength(payloadLength: Int? = nil) -> Int {
        var length: Int
        if payloadLength != nil {
            length = payloadLength!
        } else {
            length = Int(Options.MTU)
        }
        length -= Int(headerLength)
        
        return maxDataLength(length)
    }
}
