//
//  SocketWrapper.swift
//  
//
//  Created by Andrea G on 16/06/2023.
//

import Foundation
import Network

typealias SocketResponseCompletion = @Sendable (Result<SocketResponse, Error>) -> Void

public final class SocketWrapper: Sendable {
    private let requestMarker: [UInt8]
    private let host: NWEndpoint.Host
    private let port: NWEndpoint.Port
    private let connection: NWConnection
    private nonisolated(unsafe) var sendRequestInitiated = false
    private nonisolated(unsafe) var data = Data()
    private nonisolated(unsafe) var startingTime: TimeInterval = 0
    private nonisolated(unsafe) var timer: Timer?
    private let queue = DispatchQueue(label: "com.gameServerQueryLibrary.socketQueue")
    private nonisolated(unsafe) var completionHandler: SocketResponseCompletion?
    private let dispatchQueue = DispatchQueue(label: "com.gsql.socket-queue")

    deinit {
        cleanup()
    }
    
    init(requestMarker: [UInt8], host: NWEndpoint.Host, port: NWEndpoint.Port) {
        self.requestMarker = requestMarker
        self.host = host
        self.port = port
        connection = NWConnection(host: host, port: port, using: .udp)
        observeConnectionStateUpdates()
        connection.start(queue: queue)
    }
    
    private func observeConnectionStateUpdates() {
        connection.stateUpdateHandler = { [weak self] (newState) in
            self?.dispatchQueue.async { [weak self] in
                guard let self else {
                    return
                }
                switch (newState) {
                case .ready:
                    if sendRequestInitiated {
                        let data = Data(requestMarker)
                        sendRequest(data)
                    }
                case .failed(let error):
                    self.completionHandler?(.failure(error))
                default:
                    break
                }
            }
        }
    }
    
    func sendRequest(_ completionHandler: @escaping SocketResponseCompletion) {
        dispatchQueue.async { [weak self] in
            guard let self else {
                return
            }
            sendRequestInitiated = true
            self.completionHandler = completionHandler
            
            if connection.state == .ready {
                let data = Data(requestMarker)
                sendRequest(data)
            }
        }
    }
    
    func startTimer() {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            self.timer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(self.didNotReceiveResponseInTime), userInfo: nil, repeats: false)
        }
    }
    
    func cancel() {
        cleanup()
    }

    private func sendRequest(_ content: Data) {
        connection.send(content: content, completion: NWConnection.SendCompletion.contentProcessed(({ [weak self] error in
            self?.dispatchQueue.async { [weak self] in
                if let error {
                    self?.completionHandler?(.failure(error))
                } else {
                    self?.startingTime = Date.timeIntervalSinceReferenceDate
                }
            }
        })))
        
        startTimer()
        
        listenForDatagrams()
    }

    private func listenForDatagrams() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8_192) { [weak self] (data, context, isComplete, error) in
            self?.dispatchQueue.async { [weak self] in
                guard let self else {
                    return
                }
                if isComplete {
                    self.invalidateTimer()
                    if let data {
                        self.data.append(data)
                    }
                    let runningTime = ((Date.timeIntervalSinceReferenceDate - self.startingTime) * 1000).rounded()
                    let response = SocketResponse(data: self.data, runningTime: Int(runningTime))
                    self.completionHandler?(.success(response))
                    return
                }
                if let error {
                    NLog.error(error)
                    self.completionHandler?(.failure(error))
                    return
                } else if let data {
                    self.data.append(data)
                    self.listenForDatagrams()
                }
            }
        }
    }
    
    @objc private func didNotReceiveResponseInTime(_ timer: Timer) {
        dispatchQueue.async { [weak self] in
            guard let self else {
                return
            }
            completionHandler?(.failure(SocketError.timeout(host.debugDescription, port.rawValue)))
            cleanup()
        }
    }
    
    private func invalidateTimer() {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            self.timer?.invalidate()
            self.timer = nil
        }
    }
    
    private func cleanup() {
        dispatchQueue.async { [weak self] in
            guard let self else {
                return
            }
            invalidateTimer()
            completionHandler = nil
            connection.cancel()
        }
    }
}
