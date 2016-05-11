//
//  enums.swift
//  TunnelPacketKit
//
//  Created by Zhuhao Wang on 16/1/17.
//  Copyright © 2016年 Zhuhao Wang. All rights reserved.
//

import Foundation

enum IPVersion: UInt8 {
    case IPv4 = 4, IPv6 = 6
}

enum PacketType: UInt8 {
    case TCP = 6, UDP = 17, ICMP = 1
}

struct ControlType: OptionSetType {
    let rawValue: UInt8

    static let URG = ControlType(rawValue: 1 << 5)
    static let ACK = ControlType(rawValue: 1 << 4)
    static let PSH = ControlType(rawValue: 1 << 3)
    static let RST = ControlType(rawValue: 1 << 2)
    static let SYN = ControlType(rawValue: 1 << 1)
    static let FIN = ControlType(rawValue: 1)
}

enum TCPState {
    case CLOSED, // the initial state for new TCP tunnel
    LISTEN, // never used
    SYN_SENT, // never used
    SYN_RECEIVED, // received SYN from client, should send SYN and ACK now
    ESTABLISHED, // sending and recieving data
    FIN_WAIT_1, // send FIN packet
    FIN_WAIT_2, // received the ACK packet for FIN packet
    CLOSE_WAIT, // received FIN packet in ESTABLISHED state and send ACK for it
    CLOSING, // never used
    LAST_ACK, // send FIN for CLOSE_WAIT, waiting for ACK reply
    TIME_WAIT // not necessary since this is not a full ip stack.
}

struct TCPTunnelFlag: OptionSetType {
    let rawValue: UInt8

    static let ACKNow = TCPTunnelFlag(rawValue: 1) // send ACK as soon as possible
    static let ACKDelayed = TCPTunnelFlag(rawValue: 1 << 1) // send ACK with data or in next write time interval
    static let StopReceive = TCPTunnelFlag(rawValue: 1 << 2) // tunnel is closed locally
    static let StopSend = TCPTunnelFlag(rawValue: 1 << 3) // FIN is enqueued
}

struct TCPReceiveFlag: OptionSetType {
    let rawValue: UInt8

    static let GotRST = TCPReceiveFlag(rawValue: 1) // got RST
    static let Closed = TCPReceiveFlag(rawValue: 1 << 1) // got ACK for FIN
    static let GotFIN = TCPReceiveFlag(rawValue: 1 << 2) // got FIN
}
