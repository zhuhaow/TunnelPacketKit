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

class ChecksumSpec: QuickSpec {
    override func spec() {
        var bytes: [UInt16] = [0x4500, 0x0073, 0x0000, 0x4000, 0x4011, 0xb861, 0xc0a8, 0x0001,
            0xc0a8, 0x00c7]
        var validData: NSData!

        beforeEach {
//            let bundle = NSBundle(forClass: self.dynamicType)
//            let file = bundle.pathForResource("Packet_1", ofType: "bin")!
//            let data = NSData(contentsOfFile: file)!
//            packetData = data.subdataWithRange(NSMakeRange(14, data.length - 14))

            validData = NSData(bytesNoCopy: &bytes, length: 20, freeWhenDone: false)
        }

        describe("The checksum helper") {
            it("Can compute packet checksum") {
                NSLog("\(validData)")
                expect(Checksum.computeChecksumUnfold(validData)) == 196605
                expect(Checksum.computeChecksum(validData)) == 0
            }
        }
    }
}
