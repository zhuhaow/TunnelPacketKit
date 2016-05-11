//
//  DataBlock.swift
//  TunnelPacketKit
//
//  Created by Zhuhao Wang on 16/1/26.
//  Copyright © 2016年 Zhuhao Wang. All rights reserved.
//

import Foundation

class TCPDataBlock {
    /// Continuous data stored in tuple as (data, offsetIndex, endIndex).
    var datagrams: [(NSData, Int, Int)]
    var dataLength: Int
    var startSequence: UInt32
    var endSequence: UInt32
    var FIN = false
    
    init(fromPacket packet: IPPacket) {
        datagrams = [(packet.datagram!, packet.tcpPacket!.dataOffsetInDatagram, packet.datagram!.length)]
        dataLength = packet.tcpPacket!.dataLength
        startSequence = packet.startSequence
        endSequence = packet.endSequence
        FIN = packet.tcpPacket!.FIN
    }
    
    /**
     Take in the packet if this packet is contained or can be appended to this data block.
     
     - parameter packet: The packet to be taken in.
     
     - returns: If this data block has taken in this packet.
     */
    func takeIn(packet: IPPacket) -> Bool {
        guard let tcpPacket = packet.tcpPacket else {
            return false
        }
        
        if TCPUtils.sequenceGreaterThanOrEqualTo(tcpPacket.startSequence, startSequence) && TCPUtils.sequenceLessThanOrEqualTo(tcpPacket.endSequence, endSequence) {
            // Got a duplicated packet already contained, just takes it in.
            return true
        }
        
        if TCPUtils.sequenceBetween(tcpPacket.startSequence, startSequence, endSequence) && TCPUtils.sequenceGreaterThan(tcpPacket.endSequence, endSequence) {
            // have new data can be appended
            let offset = tcpPacket.dataOffsetInDatagram + Int(endSequence - tcpPacket.startSequence)
            let end = tcpPacket.datagram!.length
            datagrams.append((tcpPacket.datagram!, offset, end))
            
            dataLength += end - offset
            endSequence = tcpPacket.endSequence
            // we should only take the FIN from the last packet.
            FIN = FIN || tcpPacket.FIN
            return true
        }
        
        return false
    }
    
    /**
     Merge the two data block if possible.
     - note: Only appendation is considered.
     
     - parameter block: The block to be merged.
     
     - returns: If the block is merged.
     */
    func merge(block: TCPDataBlock) -> Bool {
        guard TCPUtils.sequenceGreaterThanOrEqualTo(endSequence &+ 1, block.startSequence) else {
            return false
        }
        
        block.skipToSequenceNumber(endSequence)
        datagrams.appendContentsOf(block.datagrams)
        dataLength += block.dataLength
        endSequence = block.endSequence
        FIN = FIN || block.FIN
        
        return true
    }
    
    func skipToSequenceNumber(sequenceNumber: UInt32) {
        guard datagrams.count > 0 else {
            return
        }
        
        if TCPUtils.sequenceLessThan(endSequence, sequenceNumber) {
            datagrams = []
            startSequence = sequenceNumber
            endSequence = sequenceNumber
            dataLength = 0
            FIN = false
            return
        }
        
        while TCPUtils.sequenceLessThan(startSequence, sequenceNumber) {
            // the packet should not contain SYN anyway, this case is ignored.
            // we assume the only case that `dataLength != endSequence - startSequence` is that FIN is received at the last data packet, thus we can assume the following is right.
            let firstDataEnd = startSequence &+ UInt32(datagrams[0].2 - datagrams[0].1)
            if TCPUtils.sequenceLessThan(firstDataEnd, sequenceNumber) {
                // remove first data object
                datagrams.removeFirst()
                startSequence = firstDataEnd &+ 1
                dataLength -= datagrams[0].2 - datagrams[0].1
            } else {
                datagrams[0].1 += Int(sequenceNumber &- startSequence)
                dataLength -= Int(sequenceNumber &- startSequence)
                startSequence = sequenceNumber
                return
            }
        }
    }
    
    func getData() -> NSData {
        let data = NSMutableData(capacity: dataLength)!
        var offset = 0
        for (datagram, offsetIndex, endIndex) in datagrams {
            data.replaceBytesInRange(NSMakeRange(offset, endIndex - offsetIndex), withBytes: datagram.bytes.advancedBy(offsetIndex))
            offset += endIndex - offsetIndex
        }
        return data
    }
}
