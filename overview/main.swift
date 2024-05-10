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

let nTPServer = "time.apple.com"
// get by ping "time.google.com"
let serverPort: UInt16 = 123

func getTimeStampFromNTPServer() {
    // check out this blog: https://lettier.github.io/posts/2016-04-26-lets-make-a-ntp-client-in-c.html
    var ntpPacket = ntp_packet()
    ntpPacket.li_vn_mode = 0b00011011
    
    /// get the time server's ip address
    var hints = addrinfo()
    hints.ai_family = AF_INET
    hints.ai_socktype = SOCK_DGRAM
    hints.ai_flags = AI_PASSIVE
    
    var result = addrinfo()
    let (sockFd, connectRet) = withUnsafePointer(to: hints) { hintsPointer -> (Int32, Int32) in
        return withUnsafeMutablePointer(to: &result) {
            var resultPointer: UnsafeMutablePointer<addrinfo>? = $0
            let getServerInfoRet = getaddrinfo(
                nTPServer,
                "\(serverPort)",
                hintsPointer, &resultPointer
            )
            guard getServerInfoRet == 0 else {
                fatalError("can get the time server's ip address")
            }
            
            /// use the first address
            guard let serverAddr = resultPointer?.pointee,
                  let serverAddrInPointer = UnsafeRawPointer(serverAddr.ai_addr)?.assumingMemoryBound(to: sockaddr_in.self) else {
                fatalError("can get the time server's ip address")
            }
            let serverAddrIn = serverAddrInPointer.pointee
            
            // setup the socket
            let sockFd = socket(serverAddr.ai_family, serverAddr.ai_socktype, serverAddr.ai_protocol)
            guard sockFd >= 0 else {
                fatalError("socket error")
            }
            
            #if DEBUG
            if let ipCharArray = inet_ntoa(serverAddrIn.sin_addr) {
                print("connecting to: \(String(cString: ipCharArray))")
            }
            #endif
            let connectRet = connect(
                sockFd,
                serverAddr.ai_addr,
                serverAddr.ai_addrlen
            )
            
            freeaddrinfo(resultPointer)
            return (sockFd, connectRet)
        }
    }
    
    guard connectRet == 0 else {
        fatalError("connect error: \(errno)")
    }
    
    // send a NTP packet
    print("sending ntp packet")
    let sent = write(sockFd, &ntpPacket, MemoryLayout.size(ofValue: ntpPacket))
    guard sent >= 0 else {
        fatalError("write to socket error")
    }
    
    print("recive ntp packet")
    let received = read(sockFd, &ntpPacket, MemoryLayout.size(ofValue: ntpPacket))
    guard received >= 0 else {
        fatalError("reading from socket error: \(errno)")
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
