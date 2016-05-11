//
//  ProtocolPacket.swift
//  TunnelPacketKit
//
//  Created by Zhuhao Wang on 16/1/17.
//  Copyright © 2016年 Zhuhao Wang. All rights reserved.
//

import Foundation

/// Base class for any packet.
class Packet {
    /// The datagram.
    /// - seealso: `payloadOffset`
    var datagram: NSData?
    /// The offset of this packet's payload in datagram.
    /// - note: In order to archive zero-copy in parsing and building packet, we share the `datagram` in `IPPacket` and the protocol packet (e.g., TCP, UDP) it contains, with the `payloadOffset` marking the offset.
    var payloadOffset: Int = 0
    /// The length of the payload.
    /// - note: This returns the total length of the recevied payload data object, not the payload of current packet.
    var payloadLength: Int {
        if let datagram = datagram {
            return datagram.length - payloadOffset
        } else {
            return 0
        }
    }

    /// Return the mutable version of the datagram
    /// - warning: The datagram must be able to be case into NSMutableData.
    var mutableDatagram: NSMutableData {
        return datagram as! NSMutableData
    }

    /**
     Initialize a packet with datagram and offset of the payload.

     - parameter datagram: Data of the datagram.
     - parameter offset:   The offset of the payload of current packet.
     */
    init(_ datagram: NSData? = nil, andOffset offset: Int = 0) {
        self.datagram = datagram
        self.payloadOffset = offset
    }

    /**
     Parse the payload and get all the information.

     - returns: If sucessfully parsed the packet or not.
     */
    func parsePacket() -> Bool {
        return false
    }

    /**
     Validate if the current packet is valid based on the Checksum.
     - Note: This is not needed in real application since there usually is no error in intranet.

     - returns: If the packet is valid or not.
     */
    func validate() -> Bool {
        // there is simply no need to verify the packet data against checksum
        return true
    }

    /**
     Generate the payload of the current packet.
     - warning: Should only be called after the payload length of the current packet can be determined by `computePacketLength()`.
     - seealso: `computePacketLength()`

     - returns: If the packet is build successfully or not.
     */
    func buildPacket() -> Bool {
        createMutableDatagram()
        return true
    }

    /**
     Compute and set the checksum.
     - note: This should be called in the last since it requires that everything else in payload is set. Any further modification invalidate this packet and requires resetting the checksum.

     - parameter withInitChecksum: This is useful with protocol like TCP which requires the checksum of a pseudo header.
     */
    func setChecksum(withInitChecksum: UInt32 = 0) {}

    /**
     Just a helper method.
     - note: Should use it whenever possible.

     - parameter datagram: the datagram data
     - parameter offset: the offset of the payload in the datagram
     */
    func setDatagram(datagram: NSData, withOffset offset: Int = 0) {
        self.datagram = datagram
        self.payloadOffset = offset
    }

    internal func createMutableDatagram() {
        self.datagram = NSMutableData(length: computePacketLength())
    }

    func setPayloadWithUInt8(value: UInt8, at: Int) {
        var v = value
        mutableDatagram.replaceBytesInRange(NSMakeRange(at + payloadOffset, 1), withBytes: &v)
    }

    func setPayloadWithUInt16(value: UInt16, at: Int, swap: Bool = true) {
        var v: UInt16
        if swap {
            v = CFSwapInt16HostToBig(value)
        } else {
            v = value
        }
        mutableDatagram.replaceBytesInRange(NSMakeRange(at + payloadOffset, 2), withBytes: &v)
    }

    func setPayloadWithUInt32(value: UInt32, at: Int, swap: Bool = true) {
        var v: UInt32
        if swap {
            v = CFSwapInt32HostToBig(value)
        } else {
            v = value
        }
        mutableDatagram.replaceBytesInRange(NSMakeRange(at + payloadOffset, 4), withBytes: &v)
    }

    func setPayloadWithData(data: NSData, at: Int, var length: Int? = nil, from: Int = 0) {
        if length == nil {
            length = data.length - from
        }
        let pointer = data.bytes.advancedBy(from)
        mutableDatagram.replaceBytesInRange(NSMakeRange(at, length!), withBytes: pointer)
    }

    func resetPayloadAt(at: Int, length: Int) {
        mutableDatagram.resetBytesInRange(NSMakeRange(at, length))
    }
    
    /// The max size of data.
    func maxDataLength(payloadLength: Int? = nil) -> Int {
        return 0
    }

    internal func computePacketLength() -> Int {
        return 0
    }
}
