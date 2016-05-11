//
//  TCPPacketSpec.swift
//  TunnelPacketKit
//
//  Created by Zhuhao Wang on 16/1/28.
//  Copyright © 2016年 Zhuhao Wang. All rights reserved.
//

import Foundation
import Nimble
import Quick
@testable import TunnelPacketKit

class TCPPacketSpec: QuickSpec {
    override func spec() {
        var packetData: NSData!
        var packet: TCPPacket!
        beforeEach {
            let bundle = NSBundle(forClass: self.dynamicType)
            let file = bundle.pathForResource("Packet_1", ofType: "bin")!
            let data = NSData(contentsOfFile: file)!
            packetData = data.subdataWithRange(NSMakeRange(14, data.length - 14))
            let ippacket = IPPacket(packetData)
            ippacket.parsePacket()
            packet = ippacket.tcpPacket!
        }
        
        describe("The TCPPacket") {
            it ("can parse the datagram") {
                expect(packet.validate()) == true
                expect(packet.sourcePort) == 59113
                expect(packet.destinationPort) == 5223
                expect(packet.sequenceNumber) == 0x0E43196E
                expect(packet.acknowledgmentNumber) == 0xFBF65E28
                expect(packet.headerLength) == 32
                expect(packet.PSH) == true
                expect(packet.ACK) == true
                expect(packet.RST) == false
                expect(packet.FIN) == false
                expect(packet.URG) == false
                expect(packet.SYN) == false
                expect(packet.window) == 4096
                expect(packet.dataLength) == 661
            }
        }
    }
}
