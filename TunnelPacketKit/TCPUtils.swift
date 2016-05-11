//
//  TCPUtils.swift
//  TunnelPacketKit
//
//  Created by Zhuhao Wang on 16/2/6.
//  Copyright © 2016年 Zhuhao Wang. All rights reserved.
//

import Foundation

struct TCPUtils {
    static func sequenceLessThan(a: UInt32, _ b: UInt32) -> Bool {
        return Int32(bitPattern: a &- b) < 0
    }
    
    static func sequenceLessThanOrEqualTo(a: UInt32, _ b: UInt32) -> Bool {
        return Int32(bitPattern: a &- b) <= 0
    }
    
    static func sequenceGreaterThan(a: UInt32, _ b: UInt32) -> Bool {
        return Int32(bitPattern: a &- b) > 0
    }
    
    static func sequenceGreaterThanOrEqualTo(a: UInt32, _ b: UInt32) -> Bool {
        return Int32(bitPattern: a &- b) >= 0
    }
    
    /**
     Compute if `a` is between `b` and `c` (included).
     
     - parameter a: sequence number
     - parameter b: sequence number
     - parameter c: sequence number
     
     - returns: if `a` between `b` and `c`.
     */
    static func sequenceBetween(a: UInt32, _ b: UInt32, _ c: UInt32) -> Bool {
        return sequenceGreaterThanOrEqualTo(a, b) && sequenceLessThanOrEqualTo(a, c)
    }
}