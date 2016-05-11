//
//  BlockManager.swift
//  TunnelPacketKit
//
//  Created by Zhuhao Wang on 16/1/27.
//  Copyright © 2016年 Zhuhao Wang. All rights reserved.
//

import Foundation

class BlockManager {
    var blockList: LinkedList<TCPDataBlock>?
    
    func addPacket(packet: IPPacket) {
        var blockIter = blockList
        while let cBlock = blockIter {
            if cBlock.item.takeIn(packet) {
                break
            }
            blockIter = cBlock.next
        }
        
        if blockIter == nil {
            // no block takes this in
            let block = TCPDataBlock(fromPacket: packet)
            let listItem = LinkedList(item: block)
            
            if blockList == nil {
                blockList = listItem
                return
            }
            
            if TCPUtils.sequenceLessThanOrEqualTo(block.startSequence, blockList!.item.startSequence) {
                listItem.append(blockList!)
                blockList = listItem
            }
            
            var blockIter = blockList!
            while true {
                if blockIter.next == nil {
                    blockIter.append(listItem)
                    return
                }
                
                if blockIter.next!.item.startSequence > block.endSequence {
                    // since next is after current block, it must be inserted now
                    blockIter.insertAfter(listItem)
                    return
                }
                
                blockIter = blockIter.next!
            }
            
        } else {
            if let nextBlock = blockIter!.next {
                if blockIter!.item.merge(nextBlock.item) {
                    blockIter!.takeOffNext()
                }
            }
        }
    }
    
    func getData(sequenceNumber: UInt32) -> (NSData, Bool)? {
        if let block = blockList?.item {
            if TCPUtils.sequenceBetween(sequenceNumber, block.startSequence, block.endSequence) {
                block.skipToSequenceNumber(sequenceNumber)
                return (block.getData(), block.FIN)
            }
        }
        return nil
    }
}