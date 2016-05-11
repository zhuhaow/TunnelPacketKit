//
//  TCPPacket.swift
//  TunnelPacketKit
//
//  Created by Zhuhao Wang on 16/1/17.
//  Copyright © 2016年 Zhuhao Wang. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift

class TCPPacket: ProtocolPacket, OrderedPacket {
    let fixedHeaderLength = 20
    var sequenceNumber: UInt32!
    var acknowledgmentNumber: UInt32!
    /// The offset in the header.
    var _dataOffset: UInt8!
    /// The real offset in bytes.
    var dataOffset: Int {
        get {
            return Int(_dataOffset) * 4
        }
        set {
            _dataOffset = UInt8(newValue / 4)
        }
    }
    var ECN: UInt8! = 0
    var controlType: ControlType!
    var window: UInt16!
    var checksum: UInt16!
    var urgentPointer: UInt16!
    var option: TCPOption!
    
    var optionLength: Int {
        if let option = option {
            return option.length
        } else {
            return 0
        }
    }
    
    var headerLength: Int {
        return fixedHeaderLength + optionLength
    }
    
    /// This should be set before any call to any method depending on `computePacketLength()`
    var lengthOfDataToSend: Int = 0
    
    // MARK: Flags Accessors
    var URG: Bool {
        get {
            return controlType.contains(.URG)
        }
        set {
            if newValue {
                controlType.intersectInPlace(.URG)
            } else {
                controlType.subtractInPlace(.URG)
            }
        }
    }
    
    var ACK: Bool {
        get {
            return controlType.contains(.ACK)
        }
        set {
            if newValue {
                controlType.intersectInPlace(.ACK)
            } else {
                controlType.subtractInPlace(.ACK)
            }
        }
    }
    
    var PSH: Bool {
        get {
            return controlType.contains(.PSH)
        }
        set {
            if newValue {
                controlType.intersectInPlace(.PSH)
            } else {
                controlType.subtractInPlace(.PSH)
            }
        }
    }
    
    var RST: Bool {
        get {
            return controlType.contains(.RST)
        }
        set {
            if newValue {
                controlType.intersectInPlace(.RST)
            } else {
                controlType.subtractInPlace(.RST)
            }
        }
    }
    
    var SYN: Bool {
        get {
            return controlType.contains(.SYN)
        }
        set {
            if newValue {
                controlType.intersectInPlace(.SYN)
            } else {
                controlType.subtractInPlace(.SYN)
            }
        }
    }
    
    var FIN: Bool {
        get {
            return controlType.contains(.FIN)
        }
        set {
            if newValue {
                controlType.intersectInPlace(.FIN)
            } else {
                controlType.subtractInPlace(.FIN)
            }
        }
    }
    
    /// The length of data contained in the packet.
    var dataLength: Int {
        return datagram!.length - dataOffsetInDatagram
    }
    
    /// The length of this packet based on sequence number.
    var sequenceLength: Int {
        if controlType.contains(.FIN) || controlType.contains(.SYN) {
            return dataLength + 1
        } else {
            return dataLength
        }
    }
    
    /// If there is any data in this packet.
    var dataAvailable: Bool {
        return dataLength > 0
    }
    
    /// The offset of data in the datagram.
    /// Use this name since `dataOffset` is already taken as the variable for the header field.
    override var dataOffsetInDatagram: Int {
        return dataOffset + payloadOffset
    }
    
    /// Get data.
    var data: NSData {
        return datagram!.subdataWithRange(NSMakeRange(dataOffsetInDatagram, dataLength))
    }
    
    /// If this packet has option field.
    var hasOption: Bool {
        return dataOffset > fixedHeaderLength
    }
    
    // MARK: OrderedPacket Protocol
    var startSequence: UInt32 {
        return sequenceNumber
    }
    
    var endSequence: UInt32 {
        return sequenceNumber + UInt32(sequenceLength)
    }
    
    override func parsePacket() -> Bool {
        let scanner = BinaryDataScanner(data: datagram!, littleEndian: false)
        scanner.skipTo(payloadOffset)
        
        sourcePort = scanner.read16()!
        destinationPort = scanner.read16()!
        sequenceNumber = scanner.read32()!
        acknowledgmentNumber = scanner.read32()!
        
        var info = scanner.readByte()!
        // dataOffset returns the real dataOffset in 8bit
        _dataOffset = info >> 4
        
        // ignore ECN info
        info = scanner.readByte()!
        controlType = ControlType(rawValue: info & 0x3F)
        
        window = scanner.read16()!
        checksum = scanner.read16()!
        urgentPointer = scanner.read16()!
        
        parseOptions()
        
        return true
    }
    
    private func parseOptions() {
        option = TCPOption()
        if hasOption {
            option.parseDatagram(datagram!, offset: payloadOffset + fixedHeaderLength, to: dataOffsetInDatagram)
        }
    }
    
    /**
     Build the TCP packet based on current information.
     - note: Since TCP packet is contained in IP packet, the datagram shoule already be created by `IPPacket`. If not, datagram should be set first with `setDataGram`
     - note: Data is not set yet.
     
     - returns: If the packet successfully built.
     */
    override func buildPacket() -> Bool {
        dataOffset = headerLength
        
        setPayloadWithUInt16(sourcePort, at: 0)
        setPayloadWithUInt16(destinationPort, at: 2)
        setPayloadWithUInt32(sequenceNumber, at: 4)
        setPayloadWithUInt32(acknowledgmentNumber, at: 8)
        setPayloadWithUInt8(_dataOffset << 4, at: 12)
        setPayloadWithUInt8(controlType.rawValue, at: 13)
        setPayloadWithUInt16(window, at: 14)
        // reset checksum and urgent pointer
        resetPayloadAt(16, length: 4)
        if let option = option {
            option.setOptionInPacket(self, offset: fixedHeaderLength)
        }
        
        return true
    }
    
    override internal func computePacketLength() -> Int {
        return 20 + optionLength + lengthOfDataToSend
    }
    
    override func maxDataLength(payloadLength: Int?) -> Int {
        guard let payloadLength = payloadLength else {
            DDLogError("Must know max payload lenth before compute max data length can be embeded in current TCP packet, try to use the best value possible.")
            return Int(Options.localTCPMSS) - Int(optionLength)
        }
        let dataLength = payloadLength - headerLength
        return Int(Options.localTCPMSS) < dataLength ? Int(Options.localTCPMSS) : dataLength
    }
    
    override func setChecksum(withPseudoHeaderChecksum: UInt32) {
        setPayloadWithUInt16(Checksum.computeChecksum(datagram!, from: payloadOffset, withPseudoHeaderChecksum: withPseudoHeaderChecksum), at: 16, swap: false)
    }
    
    /**
     If this packet contains the given sequence.
     
     - parameter sequence: The sequence number to be checked.
     
     - returns: If this packet contains this sequence.
     */
    func containSequence(sequence: UInt32) -> Bool {
        if startSequence <= sequence && endSequence > sequence {
            return true
        } else {
            return false
        }
    }
    
    //    func findSequenceData(sequence: UInt32) -> UnsafePointer<Void>? {
    //        if containSequence(sequence) {
    //            return datagram!.bytes.advancedBy(payloadOffset + dataOffset + Int(sequence - sequenceNumber))
    //        } else {
    //            return nil
    //        }
    //    }
}

class TCPOption {
    var MSS: UInt16?
    var windowScale: UInt8? {
        get {
            if let ws = _windowScale {
                return ws > 14 ? 14 : ws
            }
            return nil
        }
        set {
            _windowScale = newValue
        }
    }
    private var _windowScale: UInt8?
    var _length: Int?
    var length: Int {
        get {
            if let len = _length {
                return len
            } else {
                return computeLength()
            }
        }
        set {
            _length = newValue
        }
    }
    
    init() {}
    
    func parseDatagram(datagram: NSData, offset: Int, to: Int) {
        length = to - offset
        let scanner = BinaryDataScanner(data: datagram, littleEndian: false)
        scanner.skipTo(offset)
        
        scanLoop: while scanner.position < to {
            let kind = scanner.readByte()!
            guard kind != 0 else {
                break
            }
            
            switch kind {
            case 1:
                break
            case 2:
                // MSS
                let length = scanner.readByte()!
                // expect length to be 4
                guard length != 4 else {
                    DDLogError("Invalid MSS option, length should be 4 instead of \(length)")
                    break scanLoop
                }
                MSS = scanner.read16()!
            case 3:
                // Window Scale
                let length = scanner.readByte()!
                guard length != 3 else {
                    DDLogError("Invalid Window Scale option, length should be 3 instead of \(length)")
                    break scanLoop
                }
                windowScale = scanner.readByte()!
            default:
                // does not support any other options for now
                let length = scanner.readByte()!
                for _ in 0..<(length-2) {
                    scanner.readByte()!
                }
            }
        }
    }
    
    private func computeLength() -> Int {
        var length = 0
        if MSS != nil {
            length += 4
        }
        if windowScale != nil {
            length += 3
        }
        // length should be the multiple of 4
        length = Int(ceil(Float(length) / Float(4)) * 4)
        return length
    }
    
    func setOptionInPacket(tcpPacket: TCPPacket, offset: Int) {
        tcpPacket.resetPayloadAt(offset, length: computeLength())
        var currentOffset = offset
        if MSS != nil {
            tcpPacket.setPayloadWithUInt8(2, at: currentOffset)
            tcpPacket.setPayloadWithUInt8(4, at: currentOffset + 1)
            tcpPacket.setPayloadWithUInt16(MSS!, at: currentOffset + 2)
            currentOffset += 4
        }
        if windowScale != nil {
            tcpPacket.setPayloadWithUInt8(3, at: currentOffset)
            tcpPacket.setPayloadWithUInt8(3, at: currentOffset + 1)
            tcpPacket.setPayloadWithUInt8(windowScale!, at: currentOffset + 2)
            currentOffset += 3
        }
    }
    
}
