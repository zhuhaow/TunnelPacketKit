//
//  SequenceManager.swift
//  TunnelPacketKit
//
//  Created by Zhuhao Wang on 16/1/22.
//  Copyright © 2016年 Zhuhao Wang. All rights reserved.
//

import Foundation

class SequenceManager<T> : SequenceType {
    var list: LinkedList<T>?
    
    func generate() -> AnyGenerator<T> {
        var iterator: LinkedList<T>? = list
        return anyGenerator {
            if let iter = iterator {
                defer {
                    iterator = iter.next
                }
                return iter.item
            } else {
                return nil
            }
        }
    }
}

class SequencePacketManager: SequenceManager<IPPacket> {
    var sequenceNumber: UInt32? {
        return list?.item.startSequence
    }
    
    func insertPacket(packet: IPPacket) {
        let listItem: LinkedList<IPPacket> = LinkedList(item: packet)
        
        if list == nil {
            list = listItem
            return
        }
        
        if let list = list {
            var iter = list
            
            while true {
                if iter.next == nil {
                    iter.next = listItem
                    return
                } else {
                    if TCPUtils.sequenceLessThanOrEqualTo(iter.item.startSequence, packet.tcpPacket!.sequenceNumber) &&
                         TCPUtils.sequenceLessThan(packet.tcpPacket!.sequenceNumber, iter.next!.item.startSequence) {
                            iter.insertAfter(listItem)
                            return
                    } else {
                        iter = iter.next!
                    }
                }
            }
        }
    }
    
    // not include the number
    func removeBefore(sequenceNumber: UInt32) {
        while true {
            guard let iter = list else {
                return
            }
            
            if TCPUtils.sequenceLessThan(iter.item.endSequence, sequenceNumber) {
                list = iter.next
            } else {
                return
            }
        }
    }
}
