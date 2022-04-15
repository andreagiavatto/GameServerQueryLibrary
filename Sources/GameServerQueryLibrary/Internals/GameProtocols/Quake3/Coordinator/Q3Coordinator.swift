//
//  Q3Coordinator.swift
//  Q3ServerBrowser
//
//  Created by Andrea Giavatto on 3/7/14.
//
//

import Foundation
import CocoaAsyncSocket

class Q3Coordinator: NSObject, Coordinator {
    
    public weak var delegate: CoordinatorDelegate?

    fileprivate let serverController = Q3ServerController()
    private(set) var serversList = [Server]()
    private var toRequestInfo = [Server]()
    private let masterServerController = Q3MasterServerController(queue: DispatchQueue(label: "com.gsql.q3-master-server.queue"), socket: GCDAsyncUdpSocket())
    private let serverOperationsQueue = DispatchQueue(label: "com.gsql.q3-server-operations.queue")
    
    public override init() {
        super.init()
        masterServerController.delegate = self
        serverController.delegate = self
    }
    
    public func getServersList(host: String, port: String) {
        clearServers()
        masterServerController.startFetchingServersList(host: host, port: port)
    }
    
    func refreshStatus(for servers: [Server]) {
        clearServers()
        serversList = servers
        toRequestInfo.append(contentsOf: serversList)
        delegate?.didFinishFetchingServersList(for: self)
    }
    
    public func fetchServersInfo() {
        guard !toRequestInfo.isEmpty else {
            return
        }
        serverController.requestServersInfo(toRequestInfo)
        toRequestInfo.removeAll()
    }

    public func info(forServer server: Server) {
        serverController.infoForServer(ip: server.ip, port: server.port)
    }
    
    public func status(forServer server: Server) {
        serverController.statusForServer(ip: server.ip, port: server.port)
    }
    
    func server(ip: String, port: String) -> Server? {
        return serversList.first(where: {$0.ip == ip && $0.port == port})
    }
    
    @discardableResult
    func removeTimeoutServer(ip: String, port: String) -> Server? {
        if let index = serversList.firstIndex(where: {$0.ip == ip && $0.port == port}) {
            let server = serversList[index]
            serversList.remove(at: index)
            return server
        }
        return nil
    }
    
    func clearServers() {
        serversList.removeAll()
        toRequestInfo.removeAll()
        serverController.clearPendingRequests()
    }
}

extension Q3Coordinator: MasterServerControllerDelegate {
    
    func didStartFetchingServers(forMasterController controller: MasterServerController) {
        
        delegate?.didStartFetchingServersList(for: self)
    }
    
    func masterController(_ controller: MasterServerController, didFinishFetchingServersWith data: Data) {
        let servers = Q3Parser.parseServers(data)
        for ip in servers {
            let address: [String] = ip.components(separatedBy: ":")
            serversList.append(Server(ip: address[0], port: address[1]))
        }
        
        toRequestInfo.append(contentsOf: serversList)
        delegate?.didFinishFetchingServersList(for: self)
    }
    
    func masterController(_ controller: MasterServerController, didFinishWithError error: Error?) {

    }
}

extension Q3Coordinator: ServerControllerDelegate {
    
    func serverController(_ controller: ServerController, didFinishFetchingServerInfoWith operation: QueryOperation) {

        guard let server = server(ip: operation.ip, port: "\(operation.port)") else {
            return
        }
        
        if let serverInfo = Q3Parser.parseServer(operation.data) {
            server.update(with: serverInfo, ping: String(format: "%.0f", (operation.executionTime * 1000).rounded()))
            delegate?.coordinator(self, didFinishFetchingInfoFor: server)
        } else {
            delegate?.coordinator(self, didFailWith: .parseError(server))
        }
    }
    
    func serverController(_ controller: ServerController, didFinishFetchingServerStatusWith operation: QueryOperation) {
  
        guard let server = server(ip: operation.ip, port: "\(operation.port)") else {
            return
        }
        
        if let serverStatus = Q3Parser.parseServerStatus(operation.data) {
            server.rules = serverStatus.rules
            server.players = serverStatus.players.sorted { (first, second) -> Bool in
                guard let firstScore = Int(first.score), let secondScore = Int(second.score) else {
                    return false
                }
                return firstScore > secondScore
            }
            server.update(currentPlayers: String(serverStatus.players.count), ping: String(format: "%.0f", (operation.executionTime * 1000).rounded()))
            delegate?.coordinator(self, didFinishFetchingStatusFor: server)
        } else {
            delegate?.coordinator(self, didFailWith: .parseError(server))
        }
    }
    
    func serverController(_ controller: ServerController, didTimeoutFetchingServerInfoWith operation: QueryOperation) {
        
        _ = serverOperationsQueue.sync {
            removeTimeoutServer(ip: operation.ip, port: String(operation.port))
        }
    }
    
    func serverController(_ controller: ServerController, didFinishWithError error: Error?) {
        delegate?.coordinator(self, didFailWith: .custom(error?.localizedDescription))
    }
    
    func serverController(_ controller: ServerController, didFinishFetchingServersInfo: [Server]) {
        delegate?.didFinishFetchingServersInfo(for: self)
    }
}
