//
//  main.swift
//  socket-connection-server
//
//  Created by Alex on 2024/4/24.
//

import Foundation

func runServer() {
    let sd1 = socket(AF_INET, SOCK_STREAM, 0)
    var sd2: Int32 = -1
    /// clean up
    defer {
        if sd1 >= 0 {
            close(sd1)
        }
        if sd2 >= 0 {
            close(sd2)
        }
    }
   
    /// test sd1
    guard sd1 >= 0 else {
        fatalError("can't initialize a socket")
    }
    
    var on: Int32 = 1
    var ret: Int32 = 1
    ret = setsockopt(
        sd1,
        SOL_SOCKET, 
        SO_REUSEADDR,
        &on, 
        socklen_t(MemoryLayout.size(ofValue: on))
    )
    guard ret >= 0 else {
        fatalError("setsockopt(SO_REUSEADDR) failed")
    }
    
    let serverAddress = sockaddr_in(
        sin_len: 0,
        sin_family: sa_family_t(AF_INET),
        sin_port: CFSwapInt16HostToBig(serverPort),
        sin_addr: in_addr(s_addr: INADDR_ANY),
        sin_zero: (0, 0, 0, 0, 0, 0, 0, 0)
    )
    ret = bind(
        sd1,
        withUnsafePointer(to: serverAddress, {
            UnsafeRawPointer($0).assumingMemoryBound(to: sockaddr.self)
        }),
        socklen_t(MemoryLayout.size(ofValue: serverAddress))
    )
    guard ret >= 0 else {
        fatalError("bind socket failed.")
    }
    
    /// listen
    ret = listen(sd1, 10)
    guard ret >= 0 else {
        fatalError("listen socket failed.")
    }
    print("socket \(sd1) is listening on port: \(serverPort)")
    
    /// accept
    sd2 = accept(sd1, nil, nil)
    guard sd2 >= 0 else {
        fatalError("accept call failed.")
    }
    print("socket \(sd2) is accepted on port: \(serverPort)")

    /// poll
    let timeout: Int32 = 30000
    var pollFd = pollfd(fd: sd2, events: Int16(POLLIN), revents: 0)
    let nfd: nfds_t = 1
    ret = poll(&pollFd, nfd, timeout)
    guard ret > 0 else {
        if ret < 0 {
            fatalError("poll() failed")
        } else {
            fatalError("poll() timed out")
        }
    }
    
    /// prepare and receive data
    ret = setsockopt(sd2, SOL_SOCKET, SO_RCVLOWAT, &bufferLength, socklen_t(MemoryLayout.size(ofValue: bufferLength)))
    guard ret >= 0 else {
        fatalError("setsockopt for sd2 failed.")
    }
    var buffer: [UInt8] = Array(repeating: 0, count: bufferLength)
    let recvRet = recv(
        sd2,
        &buffer,
        bufferLength,
        0
    )
    guard recvRet > 0 && recvRet >= bufferLength else {
        fatalError("recv failed or received less than \(bufferLength) bytes")
    }
    print("successfully receive: \(String(cString: buffer)) with \(recvRet) bytes in total")
    
    /// echo the data back
    let sendRet = send(sd2, buffer, bufferLength, 0)
    guard sendRet == bufferLength else {
        fatalError("send failed")
    }
}
runServer()
