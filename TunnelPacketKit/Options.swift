//
//  opts.swift
//  TunnelPacketKit
//
//  Created by Zhuhao Wang on 16/1/17.
//  Copyright © 2016年 Zhuhao Wang. All rights reserved.
//

import Foundation

class Options {
    static let MTU: UInt16 = 1500
    static let localTCPMSS: UInt16 = 1420
    static let localTCPWindowScale: UInt8 = 8
    /// Time interval for fast timer in ms.
    static let fastTimerInterval: UInt64 = 200
    /// Time interval for slow timer in ms.
    static let slowTimerInterval: UInt64 = 500
    static let timerLeeway: UInt64 = 50
}
