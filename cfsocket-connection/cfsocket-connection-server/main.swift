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
        CFSocketCallBackType.readCallBack.rawValue | // 1
        CFSocketCallBackType.acceptCallBack.rawValue | // 2
        CFSocketCallBackType.connectCallBack.rawValue, // 4
        { socket, callbackType, data, _, _ in
            print("server socket callback: \(callbackType)")
            /// deal with callback
            if callbackType == CFSocketCallBackType.dataCallBack {
                /// data available for read
                guard let data = data as? Data else {
                    return
                }
                /// echo the data back
                return
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

