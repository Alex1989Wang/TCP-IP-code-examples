//
//  main.swift
//  getaddrinfo-server
//
//  Created by Alex on 2024/4/24.
//

import Foundation

func runServer() {
    /// check port number
    let args = CommandLine.arguments
    guard args.count == 2, let port = Int16(args[1]) else {
        fatalError("missing port number from the command line arguments.")
    }
    /// variables
    var hints = addrinfo(
        ai_flags: AI_PASSIVE, /* For wildcard IP address */
        ai_family: AF_UNSPEC, /* Allow IPv4 or IPv6 */
        ai_socktype: SOCK_DGRAM, /* Datagram socket */
        ai_protocol: 0, /* Any protocol */
        ai_addrlen: 0,
        ai_canonname: nil,
        ai_addr: nil,
        ai_next: nil
    )
    var result = addrinfo()
    
    /// getaddrinfo
    let ret = withUnsafeMutablePointer(to: &result) {
        var resultPointer: UnsafeMutablePointer<addrinfo>? = $0
        return withUnsafePointer(to: port) {
            let portPointer = UnsafeRawPointer($0).assumingMemoryBound(to: Int8.self)
            return getaddrinfo(
                "127.0.0.1".cString(using: .utf8),
                portPointer,
                &hints,
                &resultPointer
            )
        }
    }
    
    guard ret == 0 else {
        var reason: String = ""
        if let error = gai_strerror(ret) {
            reason = String(cString: error)
        }
        fatalError("getaddrinfo() call failed: \(reason)")
    }
}
runServer()
