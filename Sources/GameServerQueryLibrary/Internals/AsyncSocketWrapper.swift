//
//  AsyncSocketWrapper.swift
//  GameServerQueryLibrary
//
//  Created by Andrea Giavatto on 18/12/2022.
//

import Foundation
import CocoaAsyncSocket

enum SocketError: Error {
    case timeout
    case dataNotSent(Error?)
    case closed(Error?)
    case unknown
}

struct SocketResponse {
    let data: Data
    let runningTime: Int
}

fileprivate typealias SocketResponseCompletion = ((SocketResponse?, Error?) -> Void)

class AsyncSocketWrapper: NSObject {
    private(set) var responseMarker: [UInt8]!
    private(set) var eotMarker: [UInt8]?
    
    private let timeout: TimeInterval
    private var socket: GCDAsyncUdpSocket?
    private var timer: Timer?
    private var completion: SocketResponseCompletion?
    private let processingQueue = DispatchQueue(label: "com.game-server-query-library.processing-queue")
    private var startingTime: TimeInterval = 0
    private var data = Data()
    
    init(timeout: TimeInterval) {
        self.timeout = timeout
        super.init()
    }
    
    func sendRequest(ip: String, port: UInt16, requestMarker: [UInt8], responseMarker: [UInt8], eotMarker: [UInt8]?) async throws -> SocketResponse {
        return try await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<SocketResponse, Error>) in
            sendRequest(ip: ip, port: port, requestMarker: requestMarker, responseMarker: responseMarker, eotMarker: eotMarker) { response, error in
                if let response {
                    continuation.resume(returning: response)
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: SocketError.unknown)
                }
            }
        })
    }
    
    private func sendRequest(ip: String, port: UInt16, requestMarker: [UInt8], responseMarker: [UInt8], eotMarker: [UInt8]?, completion: SocketResponseCompletion?) {
        self.completion = completion
        self.responseMarker = responseMarker
        self.eotMarker = eotMarker
        
        timer = Timer.scheduledTimer(timeInterval: timeout, target: self, selector: #selector(self.didNotReceiveResponseInTime), userInfo: nil, repeats: false)
        let data = Data(requestMarker)
        socket = newSocket()
        socket?.send(data, toHost: ip, port: port, withTimeout: timeout, tag: 42)
    }
    
    func reset() {
        stopTimer()
        startingTime = 0
        completion = nil
        socket?.close()
    }
    
    @objc private func didNotReceiveResponseInTime(_ timer: Timer) {
        completion?(nil, SocketError.timeout)
        reset()
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func newSocket() -> GCDAsyncUdpSocket {
        let socket = GCDAsyncUdpSocket(delegate: self, delegateQueue: processingQueue, socketQueue: processingQueue)
        socket.setMaxReceiveIPv4BufferSize(8_192)
        socket.setMaxReceiveIPv6BufferSize(8_192)
        return socket
    }
}

extension AsyncSocketWrapper: GCDAsyncUdpSocketDelegate {
    func udpSocket(_ sock: GCDAsyncUdpSocket, didSendDataWithTag tag: Int) {
        startingTime = Date.timeIntervalSinceReferenceDate
        data = Data()
        do {
            if eotMarker != nil {
                try self.socket?.beginReceiving()
            } else {
                try self.socket?.receiveOnce()
            }
        } catch {
            completion?(nil, error)
            reset()
        }
    }
    
    func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
        self.data.append(data)
        
        let asciiRep = String(data: self.data, encoding: .ascii)
        if
            let asciiRep = asciiRep,
            let prefix = String(bytes: self.responseMarker, encoding: .ascii),
            asciiRep.hasPrefix(prefix),
            let eotMarker,
            let suffix = String(bytes: eotMarker, encoding: .ascii),
            asciiRep.range(of: suffix, options: .backwards, range: nil, locale: nil) != nil
        {
            // continuous receiving
            let start = self.data.index(self.data.startIndex, offsetBy: responseMarker.count)
            let end = self.data.endIndex
            self.data = self.data.subdata(in: start..<end)
            let runningTime = ((Date.timeIntervalSinceReferenceDate - startingTime) * 1000).rounded()
            let response = SocketResponse(data: self.data, runningTime: Int(runningTime))
            completion?(response, nil)
            reset()
        } else if
            let asciiRep = asciiRep,
            let prefix = String(bytes: self.responseMarker, encoding: .ascii),
            asciiRep.hasPrefix(prefix)
        {
            // one-time receiving
            let start = self.data.index(self.data.startIndex, offsetBy: responseMarker.count)
            let end = self.data.endIndex
            self.data = self.data.subdata(in: start..<end)
            let runningTime = ((Date.timeIntervalSinceReferenceDate - startingTime) * 1000).rounded()
            let response = SocketResponse(data: self.data, runningTime: Int(runningTime))
            completion?(response, nil)
            reset()
        } else {
            print(">>> Not finished receiving yet")
        }
    }
    
    func udpSocket(_ sock: GCDAsyncUdpSocket, didNotSendDataWithTag tag: Int, dueToError error: Error?) {
        completion?(nil, SocketError.dataNotSent(error))
        reset()
    }
    
    func udpSocketDidClose(_ sock: GCDAsyncUdpSocket, withError error: Error?) {
        if let error {
            completion?(nil, SocketError.closed(error))
            reset()
        }
    }
}
