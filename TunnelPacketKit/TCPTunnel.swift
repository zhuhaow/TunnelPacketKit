//
//  TCPTunnel.swift
//  TunnelPacketKit
//
//  Created by Zhuhao Wang on 16/1/17.
//  Copyright © 2016年 Zhuhao Wang. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift

class TCPTunnel: Tunnel {
    var state: TCPState = .CLOSED
    var ACKNow = false
    var RXClosed = false
    var TXClosed = false
    
    var _currentIPPacket: IPPacket!
    var currentIPPacket: IPPacket! {
        get {
            return _currentIPPacket
        }
        set {
            _currentIPPacket = newValue
        }
    }
    var currentTCPPacket: TCPPacket {
        get {
            return _currentIPPacket.protocolPacket as! TCPPacket
        }
    }
    
    // MARK: receive related variables
    
    /// The next sequence number expected to recieve. Packet with sequence later then this and in the window will be put in the `outOfSequenceIPPacket`.
    var nextReceiveSequenceNumber: UInt32 = 0
    /// The total size of the read window, this should be a constant.
    var readWindowSize: UInt32 = 0xFFFF
    /// The size of the available window.
    var availableReadWindowSize: UInt32 {
        // since the application will always accept unlimited data, there is no need to change this.
        return readWindowSize
    }
    var readWindowScale: UInt8 = Options.localTCPWindowScale
    /// This is the literal window size to be set in the next send packet header.
    var announceWindowSize: UInt16 {
        return UInt16(availableReadWindowSize >> UInt32(readWindowScale))
    }
    /// This is the acknowledged number in the last send ACK packet.
    var announcedReceivedSequenceNumber: UInt32 = 0
    /// If we have anything new to ACK.
    var shouldACK: Bool {
        return TCPUtils.sequenceLessThan(announcedReceivedSequenceNumber, nextReceiveSequenceNumber)
    }
    /// This is the largest sequence number we expected, we use a simple (but not standard and wrong) way to compute it. This works fine anyway.
    var announcedWindowRightEdge: UInt32 {
        return nextReceiveSequenceNumber &+ availableReadWindowSize
    }
    var receiveFlag = TCPReceiveFlag()
    let outOfSequenceIPPacket = BlockManager()
    
    
    // MARK: send related
    
    /// The sequence number of the next send packet. If the `unsendData` is not empty, then it should be the sequence number of the first packet.
    var nextSendSequenceNumber: UInt32 = 0
    /// The largest number that has been send to remote. Since sometimes packets are re-trasmitted, thus `nextSendSequenceNumber` is not the right edge of the send data. If there is no re-trasmission, this should always be one less than `nextSendSequenceNumber`.
    var largestSendSequenceNumber: UInt32 = 0
    /// The highest sequence number acknowledged by remote
    var acknowledgedSequenceNumber: UInt32 = 0
    /// The size of the announced send window.
    var sendWindowSize: UInt32 {
        return UInt32(announcedSendWindowSize) << UInt32(sendWindowScale)
    }
    /// The literal window size announced by remote TCP header in the window field.
    var announcedSendWindowSize: UInt16 = 0
    /// Send window scale set by the SYN packet
    var sendWindowScale: UInt8 = 0
    /// Current available send window.
    var availableSendWindowSize: UInt32 {
        return sendWindowSize > (nextSendSequenceNumber &- acknowledgedSequenceNumber) ?
            sendWindowSize - (nextSendSequenceNumber &- acknowledgedSequenceNumber) : 0
    }
    var sequenceNumberOfLastWindowUpdate: UInt32 = 0
    var acknowledgedNumberOfLastWindowUpdate: UInt32 = 0
    var MSS: UInt16 = 0
    var nextFlag: ControlType = ControlType()
    var nextOption: TCPOption?
    
    var unackedList = SequencePacketManager()
    var unsendPackets = [IPPacket]()
    var unsendData = DataManager()
    
    var maxSendPacketDataSize: Int {
        return Int(min(UInt32(MSS), availableSendWindowSize))
    }
    
    override init?(fromIPPacket packet: IPPacket, withManager manager: TunnelManager?) {
        super.init(fromIPPacket: packet, withManager: manager)
        
        currentIPPacket = packet
        defer {
            currentIPPacket = nil
        }
        
        guard currentTCPPacket.validate() else {
            DDLogError("Recieved an invalid TCP packet, checksum validation failed.")
            return nil
        }
        
        guard !currentTCPPacket.RST else {
            DDLogDebug("Recieved an unknown RST packet, ignored.")
            return nil
        }
        
        guard !currentTCPPacket.ACK else {
            // TODO: we should send a RST back
            DDLogDebug("Recieved an unknown ACK packet, send RST back now.")
            return nil
        }
        
        guard currentTCPPacket.SYN else {
            DDLogDebug("Recieved an unknown TCP packet with no SYN, ignored.")
            return nil
        }
        
        // The incoming packet is not processed now since we have to give a chance to set handler before any event happens.
    }
    
    override func handleIPPacket(packet: IPPacket) {
        if !packet.protocolPacket.validate() {
            DDLogError("Recieved an invalid TCP packet, checksum validation failed.")
            return
        }
        
        currentIPPacket = packet
        defer {
            currentIPPacket = nil
        }
        
        if state == .TIME_WAIT {
            processInTimeWait()
            return
        }
        
        processPacket()
        
        if receiveFlag.contains(.GotRST) {
            delegate?.reset(self)
            DDLogVerbose("TCP Tunnel \(self) got reseted by RST. Close now.")
            doClosed()
            return
        }
        
        if receiveFlag.contains(.GotFIN) {
            delegate?.remoteClosed(self)
        }
        
        output()
    }
    
    override func close() {
        sendFin()
        state = .FIN_WAIT_1
    }
    
    private func doClosed() {
        delegate?.closed(self)
        manager?.tunnelClosed(self)
    }
    
    private func processInTimeWait() {
        if currentTCPPacket.RST {
            return
        }
        
        if currentTCPPacket.SYN {
            if packetInReceiveWindow() {
                // TODO: send back an RST
                return
            }
        } else if currentTCPPacket.FIN {
            // TODO: restart the timeout
        }
        
        if currentTCPPacket.sequenceLength > 0 {
            ACKNow = true
            output()
        }
    }
    
    // MARK: input related method
    private func processPacket() {
        // reset receive flag now
        receiveFlag = TCPReceiveFlag()
        
        // handle RST
        if currentTCPPacket.RST {
            processRST()
            return
        }
        
        /* Cope with new connection attempt after remote end crashed */
        if currentTCPPacket.SYN && state != .SYN_RECEIVED {
            ACKNow = true
            return
        }
        
        switch state {
            // the initial state of new TCP tunnel
        case .CLOSED:
            // the control flag of this packet should already be checked, do not check it now
            changeStateTo(.SYN_RECEIVED)
            
            nextReceiveSequenceNumber = currentTCPPacket.sequenceNumber &+ 1
            
            // force update window
            sequenceNumberOfLastWindowUpdate = currentTCPPacket.sequenceNumber &- 1
            announcedSendWindowSize = currentTCPPacket.window
            
            // TODO: per the standard, number should be generated with an increasing fashion.
            nextSendSequenceNumber = arc4random()
            acknowledgedSequenceNumber = nextSendSequenceNumber
            largestSendSequenceNumber = nextSendSequenceNumber &- 1
            
            if let mss = currentTCPPacket.option.MSS {
                MSS = (Options.MTU - 40) < mss ? Options.MTU - 40 : mss
            } else {
                switch currentIPPacket.version {
                case .IPv4:
                    MSS = 536
                case .IPv6:
                    MSS = 1220
                }
            }
            
            if let ws = currentTCPPacket.option.windowScale {
                sendWindowScale = ws
            }
            
            // prepare for reply
            enqueueFlag([.SYN, .ACK])
            let option = TCPOption()
            option.MSS = Options.localTCPMSS
            option.windowScale = Options.localTCPWindowScale
            enqueueOption(option)
            // we have received the SYN from remote, waiting for the ACK for our SYN.
        case .SYN_RECEIVED:
            if currentTCPPacket.ACK {
                if TCPUtils.sequenceBetween(currentTCPPacket.acknowledgmentNumber, acknowledgedSequenceNumber &+ 1, nextSendSequenceNumber) {
                    // change state
                    changeStateTo(.ESTABLISHED)
                    
                    // call delegate
                    delegate?.tunnelEstablished(self)
                    
                    // if there is data, we should process it
                    receive()
                    
                    if receiveFlag.contains(.GotFIN) {
                        ACKNow = true
                        changeStateTo(.CLOSE_WAIT)
                    }
                } else {
                    // TODO: send RST
                }
            } else if currentTCPPacket.SYN && currentTCPPacket.sequenceNumber == nextReceiveSequenceNumber &- 1 {
                DDLogError("Received another copy of SYN, we shoule be able to handle this in the future")
            }
            // we received FIN from remote but we have not send FIN out, we should expect remote send only ACK for data we send out.
        case .CLOSE_WAIT:
            fallthrough
        case .ESTABLISHED:
            receive()
            if receiveFlag.contains(.GotFIN) {
                ACKNow = true
                changeStateTo(.CLOSE_WAIT)
            }
        // we send out FIN and expect remote to send new data or FIN.
        case .FIN_WAIT_1:
            receive()
            if receiveFlag.contains(.GotFIN) {
                // we should ACK the FIN now.
                ACKNow = true
                if currentTCPPacket.ACK && currentTCPPacket.acknowledgmentNumber == nextSendSequenceNumber {
                    // remote has acknowledged our FIN
                    changeStateTo(.TIME_WAIT)
                } else {
                    // remote hasn't ACK our FIN, so we wait.
                    changeStateTo(.CLOSING)
                }
            } else if currentTCPPacket.ACK && currentTCPPacket.acknowledgmentNumber == nextSendSequenceNumber {
                // we will not send anything more and everything we send is acknowledged now, we just wait for new data from remote or FIN.
                changeStateTo(.FIN_WAIT_2)
            }
        // remote has acknowledged the FIN we send, but hasn't send FIN yet.
        case .FIN_WAIT_2:
            receive()
            
            if receiveFlag.contains(.GotFIN) {
                ACKNow = true
                changeStateTo(.TIME_WAIT)
            }
        // everything is done expect remote hasn't ACK our FIN.
        case .CLOSING:
            receive()
            if currentTCPPacket.ACK && currentTCPPacket.acknowledgmentNumber == nextSendSequenceNumber {
                changeStateTo(.TIME_WAIT)
            }
            // TODO: what does this do?
        case .LAST_ACK:
            receive()
            if currentTCPPacket.controlType.contains(.ACK) && currentTCPPacket.acknowledgmentNumber == nextSendSequenceNumber {
                doClosed()
            }
            break
        default:
            break
        }
    }
    
    func processRST() {
        // first determine if RST is acceptable
        let acceptable = TCPUtils.sequenceBetween(currentTCPPacket.sequenceNumber, nextReceiveSequenceNumber, announcedWindowRightEdge)
        
        if acceptable {
            receiveFlag.insert(.GotRST)
        } else {
            DDLogVerbose("Received unacceptable RST packet, ignored.")
        }
    }
    
    // this should only be called later than .ESTABLISHED state
    func receive() {
        if currentTCPPacket.ACK {
            updateWindowStatus()
            
            if TCPUtils.sequenceLessThanOrEqualTo(currentTCPPacket.acknowledgmentNumber, acknowledgedSequenceNumber) {
                // we should handle duplicate ACK here if we want to
                // but skip that for now
            } else if TCPUtils.sequenceBetween(currentTCPPacket.acknowledgmentNumber, acknowledgedSequenceNumber &+ 1, largestSendSequenceNumber &+ 1) {
                // Remote ACKed new data.
                acknowledgedSequenceNumber = currentTCPPacket.acknowledgmentNumber
                updateUnackedList()
                // theoraically, it is possible to go through the unsend list to see if any is acknowleged now
                // we do not support such case for simplicity
                
                // TODO: reset re-transmit timer.
                
                // this is also the place where RTT estimation happens, but that's not need here.
            } else {
                DDLogWarn("Received out of sequence ACK, expect ACK smaller than \(largestSendSequenceNumber &+ 1), but got \(currentTCPPacket.acknowledgmentNumber). This should have no consequences, but is not expected.")
            }
        }
        
        // if there is any data in this packet and the tunnel can process it
        if currentTCPPacket.dataAvailable && [TCPState.SYN_RECEIVED, TCPState.ESTABLISHED, TCPState.FIN_WAIT_1, TCPState.FIN_WAIT_2].contains(state) {
            processData()
        }
    }
    
    private func updateUnackedList() {
        unackedList.removeBefore(acknowledgedSequenceNumber)
    }
    
    private func processData() {
        // if received data not in window, send ACK again
        guard TCPUtils.sequenceBetween(currentTCPPacket.sequenceNumber, nextReceiveSequenceNumber, nextReceiveSequenceNumber &+ readWindowSize &- 1) else {
            ACKNow = true
            return
        }
        
        outOfSequenceIPPacket.addPacket(currentIPPacket)
        if let (data, FIN) = outOfSequenceIPPacket.getData(nextReceiveSequenceNumber) {
            delegate?.receivedData(data, from: self)
            if FIN {
                receiveFlag.insert(.GotFIN)
            }
        }
    }
    
    private func updateWindowStatus() {
        // if we received new data
        if TCPUtils.sequenceLessThan(sequenceNumberOfLastWindowUpdate, currentTCPPacket.sequenceNumber) ||
            // or ACKed data received
            (sequenceNumberOfLastWindowUpdate == currentTCPPacket.sequenceNumber && TCPUtils.sequenceLessThan(acknowledgedNumberOfLastWindowUpdate, currentTCPPacket.acknowledgmentNumber)) ||
            // or nothing is new but window became larger
            (acknowledgedNumberOfLastWindowUpdate == currentTCPPacket.acknowledgmentNumber && currentTCPPacket.window > announcedSendWindowSize) {
                // set up new send window size
                announcedSendWindowSize = currentTCPPacket.window
                sequenceNumberOfLastWindowUpdate = currentTCPPacket.sequenceNumber
                acknowledgedNumberOfLastWindowUpdate = currentTCPPacket.acknowledgmentNumber
                if announcedSendWindowSize == 0 {
                    DDLogError("The send window is set to 0, this is something not expected but we should be able to handle in the future.")
                }
        }
    }
    
    func changeStateTo(state: TCPState) {
        DDLogDebug("State of tunnel \(self) changes from \(self.state) to \(state)")
        
        if state == .TIME_WAIT && self.state != .TIME_WAIT {
            delegate?.closed(self)
        }
        
        self.state = state
    }
    
    // MARK: Packet creation
    func createRawPacket() -> IPPacket {
        let packet = IPPacket()
        packet.sourceAddress = remoteIP
        packet.sourcePort = remotePort
        packet.destinationAddress = localIP
        packet.destinationPort = localPort
        let tcpPacket = TCPPacket()
        tcpPacket.sequenceNumber = nextSendSequenceNumber
        tcpPacket.window = announceWindowSize
        packet.protocolPacket = tcpPacket
        return packet
    }
    
    func exhaustFlagToPacket(packet: IPPacket) -> IPPacket {
        let tcpPacket = packet.protocolPacket as! TCPPacket
        
        tcpPacket.controlType.unionInPlace(nextFlag)
        nextFlag = ControlType()
        
        tcpPacket.option = nextOption
        nextOption = nil
        return packet
    }
    
    func createACKPacket() -> IPPacket {
        let packet = createRawPacket()
        let tcpPacket = packet.protocolPacket as! TCPPacket
        
        tcpPacket.acknowledgmentNumber = nextReceiveSequenceNumber
        tcpPacket.ACK = true
        return packet
    }
    
    func sendRSTforCurrentPacket() {
        // TODO: create right RST packet
        //        let packet = createRawPacket()
        //        let tcpPacket = packet.tcpPacket!
        //        tcpPacket.controlType = [.RST]
        //        sendPacket(packet)
    }
    
    // MARK: output related
    
    override func sendData(data: NSData) {
        guard !TXClosed else {
            DDLogError("Try to send data after TX closed.")
            return
        }
        
        unsendData.append(data)
        output()
    }
    
    func sendFin() {
        // append FIN to the last unsend packet if there is any
        if let lastPacket = unsendPackets.last {
            lastPacket.tcpPacket!.FIN = true
            return
        }
        enqueueFlag(.FIN)
    }
    
    func output(fromTimer: Bool = false) {
        var sendNow = false
        if !nextFlag.isDisjointWith([.ACK, .SYN, .FIN]) || ACKNow {
            sendNow = true
        }
        
        if unsendPackets.count > 0 {
            sendNow = true
        }
        
        if sendNow {
            outputPackets()
        }
        
        ACKNow = false
    }
    
    private func outputPackets() {
        var packets = [IPPacket]()
        // send at least one packet.
        repeat {
            let packet = createACKPacket()
            exhaustFlagToPacket(packet)
            packet.tcpPacket!.lengthOfDataToSend = min(packet.maxDataLength(), unsendData.length)
            packet.buildPacket()
            unsendData.fillTo(packet.datagram as! NSMutableData, offset: packet.tcpPacket!.dataOffsetInDatagram, length: packet.tcpPacket!.lengthOfDataToSend)
            packet.setChecksum()
            packets.append(packet)
        } while unsendData.length > 0 && sendWindowSize > 0
        
        sendPackets(packets)
        for packet in packets {
            if packet.tcpPacket!.sequenceLength > 0 {
                unackedList.insertPacket(packet)
            }
        }
    }
    
    func enqueueFlag(flag: ControlType) {
        nextFlag.intersectInPlace(flag)
    }
    
    func dequeueFlag(flag: ControlType) {
        nextFlag.subtractInPlace(flag)
    }
    
    func enqueueOption(option: TCPOption) {
        nextOption = option
    }
    
    func packetInReceiveWindow() -> Bool {
        return TCPUtils.sequenceBetween(currentTCPPacket.sequenceNumber, nextReceiveSequenceNumber, nextReceiveSequenceNumber &+ readWindowSize &- 1)
    }
    
    override func fastTimerHandler() {
        super.fastTimerHandler()
        if shouldACK {
            ACKNow = true
            output()
        }
        
        if state == .TIME_WAIT {
            doClosed()
        }
    }
}
