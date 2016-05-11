//
//  PacketSpec.swift
//  TunnelPacketKit
//
//  Created by Zhuhao Wang on 16/1/20.
//  Copyright © 2016年 Zhuhao Wang. All rights reserved.
//

import Foundation
import Nimble
import Quick
@testable import TunnelPacketKit

class IPPacketSpec: QuickSpec {
    override func spec() {
        var packetData: NSData!
        var packet: IPPacket!
        beforeEach {
            let bundle = NSBundle(forClass: self.dynamicType)
            let file = bundle.pathForResource("Packet_1", ofType: "bin")!
            let data = NSData(contentsOfFile: file)!
            packetData = data.subdataWithRange(NSMakeRange(14, data.length - 14))
            packet = IPPacket(packetData)
        }

        describe("The IPPacket") {
            it("Can parse the data") {
                expect(packet.parsePacket()) == true
                expect(packet.version) == IPVersion.IPv4
                expect(packet.headerLength) == 20
                expect(packet.totalLength) == 713
                expect(packet.TTL) == 64
                expect(packet.packetType) == PacketType.TCP
                expect(packet.sourceAddress.equalTo(IPv4Address(192, 168, 1, 230))) == true
                expect(packet.destinationAddress.equalTo(IPv4Address(17, 172, 233, 92))) == true
                expect(packet.tcpPacket).toNot(beNil())
            }

            it("Can validate packet") {
                packet.parsePacket()
                expect(packet.validate()) == true
            }
        }
    }
}
