//
//  main.swift
//  cfsocket-connection-client
//
//  Created by Alex on 2024/4/25.
//

import Foundation

func runClient() {
    print("run client ...")
    
    /// crate a socket
    let cfSocket = CFSocketCreate(
        kCFAllocatorDefault,
        AF_INET,
        SOCK_STREAM,
        IPPROTO_TCP,
        CFSocketCallBackType.connectCallBack.rawValue | CFSocketCallBackType.dataCallBack.rawValue,
        { socket, callbackType, data, _, _ in
            print("client callback: \(callbackType)")
        },
        nil
    )
    defer {
        if let cfSocket {
            /// this closes the underlying socket
            CFSocketInvalidate(cfSocket)
        }
    }
    guard let cfSocket else {
        fatalError("client failed to create a cfsocket.")
    }
    
    /// connect
    /// get server address info
    var addressHints = addrinfo(
        ai_flags: AI_ALL,
        ai_family: AF_INET,
        ai_socktype: SOCK_STREAM,
        ai_protocol: 0,
        ai_addrlen: 0,
        ai_canonname: nil,
        ai_addr: nil,
        ai_next: nil
    )
    var addrResult = addrinfo()
    let serverAddrIn = withUnsafeMutablePointer(to: &addrResult) {
        var addrPointer: UnsafeMutablePointer<addrinfo>? = $0
        defer {
            freeaddrinfo(addrPointer)
        }
        
        /// getaddrinfo
        let getAddrError = getaddrinfo(
            serverName.cString(using: .utf8),
            "\(serverPort)",
            &addressHints,
            &addrPointer
        )
        guard getAddrError == 0 else {
            var error: String = ""
            if let err = gai_strerror(getAddrError) {
                error = String(cString: err)
            }
            fatalError("getaddrinfo failed: \(error)")
        }
        
#if DEBUG
        var temp = addrPointer
        while temp != nil {
            let sockaddrIn = UnsafeRawPointer(temp!.pointee.ai_addr).assumingMemoryBound(to: sockaddr_in.self).pointee
            var addrString: String = ""
            if let address = inet_ntoa(sockaddrIn.sin_addr) {
                addrString = String(cString: address)
            }
            print("socket address: \(addrString) port: \(CFSwapInt16BigToHost(sockaddrIn.sin_port))")
            temp = temp?.pointee.ai_next
        }
#endif
        
        guard let serverAddr = addrPointer?.pointee.ai_addr else {
            fatalError("getaddrinfo returns no result.")
        }
        let serverAddrIn = UnsafeRawPointer(serverAddr).assumingMemoryBound(to: sockaddr_in.self).pointee
        return serverAddrIn
    }
    
    let sockAddrPointer = withUnsafePointer(to: serverAddrIn, {
        UnsafeRawPointer($0).assumingMemoryBound(to: sockaddr.self)
    })

    /// connect
    let addressData = NSData(bytes: sockAddrPointer, length: MemoryLayout.size(ofValue: serverAddrIn)) as CFData
    let conRet = CFSocketConnectToAddress(cfSocket, addressData, 300)
    guard conRet == .success else {
        /// check if the server program is running if connection fails
        fatalError("client can't connect to \(serverName) port: \(serverPort)")
    }
    
    /// send data
    var dataBuffer: [CChar] = Array(repeating: "a".utf8CString[0], count: bufferLength)
    dataBuffer[bufferLength - 1] = 0 // null-terminated
    let data = dataBuffer.withUnsafeBufferPointer { Data(buffer: $0) }
    let sendRet = CFSocketSendData(
        cfSocket,
        addressData,
        data as CFData,
        300
    )
    guard sendRet == .success else {
        fatalError("client can't send data to \(serverName) port: \(serverPort)")
    }
    print("successfully send data to \(serverName) port \(serverPort)")
}
runClient()

