//
//  main.swift
//  cfsocket-connection-server
//
//  Created by Alex on 2024/4/25.
//

import Foundation
import CoreFoundation

func runServer() {
    print("start server ...")
    /// create a cfsocket
    let cfSocket = CFSocketCreate(
        kCFAllocatorDefault,
        AF_INET,
        SOCK_STREAM,
        IPPROTO_TCP,
        CFSocketCallBackType.acceptCallBack.rawValue,
        { socket, callbackType, address, data, info in
            print("server socket callback: \(callbackType)")
            /// deal with callback
            if callbackType == CFSocketCallBackType.acceptCallBack {
                /// handle new connection
                /// the data parameter of the callback is a pointer to a CFSocketNativeHandle value (an integer socket number) representing the socket
                /// https://developer.apple.com/library/archive/documentation/NetworkingInternet/Conceptual/NetworkingTopics/Articles/UsingSocketsandSocketStreams.html#//apple_ref/doc/uid/CH73-SW8
                
                ///  https://developer.apple.com/documentation/corefoundation/cfsocketcallback
                guard let address = address as? Data,
                        let data = data else {
                    return
                }
                let sockAddrIn = address.withUnsafeBytes {
                    $0.load(as: sockaddr_in.self)
                }
                let handle = data.load(as: CFSocketNativeHandle.self)
                #if DEBUG
                var addrString: String = ""
                if let address = inet_ntoa(sockAddrIn.sin_addr) {
                    addrString = String(cString: address)
                }
                print("socket address: \(addrString) port: \(CFSwapInt16BigToHost(sockAddrIn.sin_port))")
                #endif
                print("accept new connection socket handle: \(handle)")
            }
        },
        nil
    )
    guard let cfSocket else {
        fatalError("can't create cfsocket")
    }
    /// set address
    /// this is probably equivilent to the bind() c function
    var serverAddress = sockaddr_in(
        sin_len: 0,
        sin_family: sa_family_t(AF_INET),
        sin_port: CFSwapInt16HostToBig(serverPort),
        sin_addr: in_addr(s_addr: INADDR_ANY),
        sin_zero: (0, 0, 0, 0, 0, 0, 0, 0)
    )
    let addressData = NSData(
        bytes: &serverAddress,
        length: MemoryLayout.size(ofValue: serverAddress)
    ) as CFData
    let ret = CFSocketSetAddress(cfSocket, addressData)
    guard ret == .success else {
        fatalError("can't set address data")
    }
    let runloopSource = CFSocketCreateRunLoopSource(kCFAllocatorDefault, cfSocket, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runloopSource, .defaultMode)
    CFRunLoopRun()
}
runServer()

