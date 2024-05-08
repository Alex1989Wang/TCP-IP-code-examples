//
//  main.swift
//  socket-connection-client
//
//  Created by Alex on 2024/4/24.
//

import Foundation

func runClient() {
    
    /// define a socket
    let sd = socket(AF_INET, SOCK_STREAM, 0)
    defer {
        if sd >= 0 {
            close(sd)
        }
    }
    guard sd >= 0 else {
        fatalError("request a socket failed.")
    }
    
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
    let serverAddrIn = withUnsafeMutablePointer(to: &addrResult) { pointer in
        var addrPointer: UnsafeMutablePointer<addrinfo>? = pointer
        defer {
            // free
            freeaddrinfo(addrPointer)
        }
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
    
    /// try connect
    let conRet = withUnsafePointer(to: serverAddrIn, {
        let sockAddrPointer = UnsafeRawPointer($0).assumingMemoryBound(to: sockaddr.self)
        let conRet = connect(
            sd,
            sockAddrPointer,
            socklen_t(MemoryLayout.size(ofValue: serverAddrIn))
        )
        return conRet
    })
    guard conRet >= 0 else {
        // if the error is: Connection refused
        // please start the server program first
        fatalError("connect() failed: \(String(cString: strerror(errno)))")
    }

    var buffer: [CChar] = Array(repeating: "a".utf8CString[0], count: bufferLength)
    buffer[bufferLength - 1] = 0 // make this buffer null-terminated, so we can use String(cString: _) later without a crash
    let sendRet = send(sd, &buffer, bufferLength, 0)
    guard sendRet >= 0 else {
        fatalError("send() failed.")
    }
    
    /// receive server's echo
    /********************************************************************/
    /* In this example we know that the server is going to respond with */
    /* the same 250 bytes that we just sent.  Since we know that 250    */
    /* bytes are going to be sent back to us, we can use the            */
    /* SO_RCVLOWAT socket option and then issue a single recv() and     */
    /* retrieve all of the data.                                        */
    /*                                                                  */
    /* The use of SO_RCVLOWAT is already illustrated in the server      */
    /* side of this example, so we will do something different here.    */
    /* The 250 bytes of the data may arrive in separate packets,        */
    /* therefore we will issue recv() over and over again until all     */
    /* 250 bytes have arrived.                                          */
    /********************************************************************/
    var bytesReceived = 0
    var receiveBuffer: [CChar] = Array(repeating: 0, count: bufferLength)
    while bytesReceived < bufferLength {
        let recvRet = recv(sd, &receiveBuffer[bytesReceived], bufferLength - bytesReceived, 0)
        if recvRet < 0 {
            print("receive failed with error number: \(errno)")
            break
        } else if recvRet == 0 {
            print("server closed connection")
            break
        }
        /// count the bytes
        bytesReceived += recvRet
    }
    /// log the received buffer
    /// add a null-teminator
    receiveBuffer[bufferLength - 1] = 0
    print("received result: \(String(cString: receiveBuffer)) number of bytes: \(bytesReceived)")
}
runClient()

