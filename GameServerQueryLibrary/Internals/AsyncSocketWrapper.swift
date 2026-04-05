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
    private let queue = DispatchQueue(label: "com.gameServerQueryLibrary.socketQueue")
    private var timeoutTask: DispatchWorkItem?
    private var continuation: CheckedContinuation<SocketResponse, Error>?
    /// How long to wait for a UDP response before giving up.  500 ms was too
    /// aggressive for servers with geographic distance or transient congestion.
    /// Callers can pass a custom value; 2 s is a sensible real-world default.
    private let requestTimeout: TimeInterval

    private var requestInProgress = false

    public init(
        requestMarker: [UInt8],
        host: NWEndpoint.Host,
        port: NWEndpoint.Port,
        timeout: TimeInterval = 2.0
    ) {
        self.requestMarker = requestMarker
        self.host = host
        self.port = port
        self.requestTimeout = timeout
        connection = NWConnection(host: host, port: port, using: .udp)
        // Install the state handler before starting the connection so we cannot
        // miss an early .ready transition that arrives before a Task could run.
        connection.stateUpdateHandler = { [weak self] newState in
            Task {
                await self?.handleNewState(newState)
            }
        }
        connection.start(queue: queue)
    }
    
    public func sendRequest() async throws -> SocketResponse {
        guard !requestInProgress else {
            throw SocketError.requestAlreadyInProgress
        }
        requestInProgress = true
        data = Data()  // clear any stale bytes from a previous request
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

    // Both finish methods nil out `continuation` immediately after resuming so
    // a second call from a racing path (e.g. timeout + connection failure) is a
    // safe no-op rather than a "tried to resume continuation more than once" crash.
    // They also reset `requestInProgress` so the socket can be reused.
    private func finish(with response: SocketResponse) async {
        guard let continuation else { return }
        self.continuation = nil
        requestInProgress = false
        continuation.resume(returning: response)
    }

    private func finish(with error: Error) async {
        guard let continuation else { return }
        self.continuation = nil
        requestInProgress = false
        continuation.resume(throwing: error)
    }

    private func cleanup() async {
        continuation = nil
        requestInProgress = false
        invalidateTimer()
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
                    if let data {
                        self.data.append(data)
                    }
                    await self.invalidateTimer()
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
        let timeoutTask = DispatchWorkItem(block: { @Sendable in
            Task {
                await self.timeout()
            }
        })
        self.timeoutTask = timeoutTask
        queue.asyncAfter(deadline: .now() + requestTimeout, execute: timeoutTask)
    }
    
    private func invalidateTimer() {
        timeoutTask?.cancel()
        timeoutTask = nil
    }
    
    private func timeout() async {
        await self.finish(with: SocketError.timeout(host.debugDescription, port.rawValue))
        await self.cleanup()
    }
}
