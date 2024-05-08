//
//  main.swift
//  overview
//
//  Created by alex.www on 2024/4/15.
//

/*
 https://lettier.github.io/posts/2016-04-26-lets-make-a-ntp-client-in-c.html
 
 The first example given in the overview chapter of book: TCP/IP Illustrated - The Implementation.
 However, the example is about a daytime server within a local test network.
 I suppose the local test network is not available to us???
 
 So, a public NTP server is used here to replicate this example.
 */
import Foundation
import Darwin

let googleNTPServer = "time.apple.com"
// get by ping "time.google.com"
let googleNTPServerIP = "17.253.116.253"
let serverPort: UInt16 = 123

func getTimeStampFromNTPServer() {
    // check out this blog: https://lettier.github.io/posts/2016-04-26-lets-make-a-ntp-client-in-c.html
    var ntpPacket = ntp_packet()
    ntpPacket.li_vn_mode = 0b00011011
    
    // setup the socket
    let sockFd = socket(PF_INET, SOCK_DGRAM, 0)
    guard sockFd >= 0 else {
        fatalError("socket error")
    }
    
    var serverAddr: sockaddr_in = sockaddr_in()
    bzero(&serverAddr, MemoryLayout.size(ofValue: serverAddr))
    serverAddr.sin_family = sa_family_t(AF_INET)
    
    // Copy the server's IP address to the server address structure.
    serverAddr.sin_port = CFSwapInt16HostToBig(serverPort)
    serverAddr.sin_addr.s_addr = inet_addr(googleNTPServerIP)
    
    let connectRet = withUnsafePointer(to: serverAddr) {
        let serverSockAddr = UnsafeRawPointer($0).assumingMemoryBound(to: sockaddr.self)
        return connect(
            sockFd,
            serverSockAddr,
            socklen_t(MemoryLayout.size(ofValue: serverAddr))
        )
    }
    guard connectRet == 0 else {
        fatalError("connect error")
    }
    
    // send a NTP packet
    let sent = write(sockFd, &ntpPacket, MemoryLayout.size(ofValue: ntpPacket))
    guard sent >= 0 else {
        fatalError("write to socket error")
    }
    
    let received = read(sockFd, &ntpPacket, MemoryLayout.size(ofValue: ntpPacket))
    guard received >= 0 else {
        fatalError("reading from socket error")
    }
    
    ntpPacket.txTm_s = CFSwapInt32BigToHost(ntpPacket.txTm_s)
    ntpPacket.txTm_f = CFSwapInt32BigToHost(ntpPacket.txTm_f)
    
    // NTP epoch: 1900
    let calendar = Calendar(identifier: .gregorian)
    var ntpEpochComponents = DateComponents()
    ntpEpochComponents.calendar = calendar
    ntpEpochComponents.year = 1900
    ntpEpochComponents.month = 1
    ntpEpochComponents.day = 1
    ntpEpochComponents.hour = 0
    ntpEpochComponents.minute = 0
    ntpEpochComponents.second = 0
    let ntpEpoch = calendar.date(from: ntpEpochComponents)
    
    let now = Date()
    let serverTime = ntpEpoch?.addingTimeInterval(TimeInterval(ntpPacket.txTm_s))
    
    print("host time: \(now) server time: \(String(describing: serverTime))")
}
getTimeStampFromNTPServer()
