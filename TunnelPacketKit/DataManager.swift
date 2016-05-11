//
//  DataManager.swift
//  TunnelPacketKit
//
//  Created by Zhuhao Wang on 16/1/24.
//  Copyright © 2016年 Zhuhao Wang. All rights reserved.
//

import Foundation

class DataManager {
    private var dataArray = [NSData]()
    var offset = 0
    var length = 0

    func append(data: NSData) {
        dataArray.append(data)
        length += data.length
    }

    func fillTo(data: NSMutableData, offset: Int, length: Int) -> Bool {
        guard length <= self.length else {
            return false
        }
        
        guard data.length >= offset + length else {
            return false
        }
        
        var lengthLeft = length
        var currentOffset = offset
        while lengthLeft > 0 {
            if dataArray[0].length - self.offset <= lengthLeft {
                // exhaust first data
                data.replaceBytesInRange(NSMakeRange(currentOffset, dataArray[0].length - self.offset), withBytes: dataArray[0].bytes.advancedBy(self.offset))
                self.offset = 0
                dataArray.removeFirst()
                lengthLeft -= dataArray[0].length - self.offset
                currentOffset += dataArray[0].length - self.offset
            } else {
                // only fills in part data in first data object
                data.replaceBytesInRange(NSMakeRange(currentOffset, lengthLeft), withBytes: dataArray[0].bytes.advancedBy(self.offset))
                currentOffset += lengthLeft
                lengthLeft = 0
            }
        }
        return true
    }
}
