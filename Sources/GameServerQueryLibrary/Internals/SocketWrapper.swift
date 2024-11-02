//
//  SocketWrapper.swift
//  
//
//  Created by Andrea G on 16/06/2023.
//

import Foundation
import Network

public final actor AsyncSocketWrapper: Sendable {
    private let requestMarker: [UInt8]
    private let host: NWEndpoint.Host
    private let port: NWEndpoint.Port
    private let connection: NWConnection
    private nonisolated(unsafe) var sendRequestInitiated = false
    private nonisolated(unsafe) var data = Data()
    private nonisolated(unsafe) var startingTime: TimeInterval = 0
    private nonisolated(unsafe) var timer: Timer?
    private let queue = DispatchQueue(label: "com.gameServerQueryLibrary.socketQueue")
    private var continuation: CheckedContinuation<SocketResponse, Error>?
    
    private var requestInProgress = false
    
    public init(requestMarker: [UInt8], host: NWEndpoint.Host, port: NWEndpoint.Port) {
        self.requestMarker = requestMarker
        self.host = host
        self.port = port
        connection = NWConnection(host: host, port: port, using: .udp)
        connection.start(queue: queue)
        Task {
            await observeConnectionStateUpdates()
        }
    }
    
    public func observeConnectionStateUpdates() async {
        connection.stateUpdateHandler = { [weak self] newState in
            Task {
                await self?.handleNewState(newState)
            }
        }
    }
    
    public func sendRequest() async throws -> SocketResponse {
        guard !requestInProgress else {
            throw SocketError.requestAlreadyInProgress
        }
        requestInProgress = true
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            Task {
                if connection.state == .ready {
                    let data = Data(requestMarker)
                    await sendRequest(data)
                }
            }
        }
    }
    
    private func finish(with response: SocketResponse) async {
        continuation?.resume(returning: response)
    }
    
    private func finish(with error: Error) async {
        continuation?.resume(throwing: error)
    }
    
    private func cleanup() async {
        continuation = nil
        await invalidateTimer()
        connection.cancel()
    }
    
    private func handleNewState(_ state: NWConnection.State) async {
        switch state {
            case .ready:
                if requestInProgress {
                    let data = Data(requestMarker)
                    await sendRequest(data)
                }
            case .failed(let error):
                await self.finish(with: error)
            default:
                break
        }
    }
    
    private func sendRequest(_ content: Data) async {
        connection.send(content: content, completion: NWConnection.SendCompletion.contentProcessed(({ [weak self] error in
            if let error {
                Task { [weak self] in
                    await self?.finish(with: error)
                }
            } else {
                self?.startingTime = Date.timeIntervalSinceReferenceDate
            }
        })))
        
        await startTimer()
        
        listenForDatagrams()
    }
    
    private func listenForDatagrams() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8_192) { (data, context, isComplete, error) in
            Task { [weak self] in
                guard let self else {
                    return
                }
                if isComplete {
                    await self.invalidateTimer()
                    if let data {
                        self.data.append(data)
                    }
                    let runningTime = ((Date.timeIntervalSinceReferenceDate - self.startingTime) * 1000).rounded()
                    let response = SocketResponse(data: self.data, runningTime: Int(runningTime))
                    await finish(with: response)
                    return
                }
                if let error {
                    NLog.error(error)
                    await finish(with: error)
                    return
                } else if let data {
                    self.data.append(data)
                    await self.listenForDatagrams()
                }
            }
        }
    }
    
    private func startTimer() async {
        await MainActor.run {
            timer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(self.didNotReceiveResponseInTime), userInfo: nil, repeats: false)
        }
    }
    
    @objc private func didNotReceiveResponseInTime() async {
        Task {
            await finish(with: SocketError.timeout(host.debugDescription, port.rawValue))
            await cleanup()
        }
    }
    
    private func invalidateTimer() async {
        await MainActor.run {
            timer?.invalidate()
            timer = nil
        }
    }
}
