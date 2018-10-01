//
//  RemoteParameterServerBrowser.swift
//  ParametersRemoteControl
//
//  Created by Avi Cieplinski on 10/1/18.
//  Copyright © 2018 Avi Cieplinski. All rights reserved.
//

import MultipeerConnectivity
import UIKit
import os.signpost

class RemoteParameterServerBrowser: NSObject {

    let myself: RemoteParameterReceiver
    weak var delegate: RemoteParameterServerBrowserDelegate?
    private let serviceBrowser : MCNearbyServiceBrowser
    private var servers: Set<ParameterServer> = []

    init(myself: RemoteParameterReceiver) {
        self.myself = myself
        serviceBrowser = MCNearbyServiceBrowser(peer: myself.peerID, serviceType: RemoteParameterService.serverService)
        super.init()
    }

    public func startBrowsing() {
        serviceBrowser.delegate = self
        serviceBrowser.startBrowsingForPeers()
    }

    deinit {
        self.serviceBrowser.stopBrowsingForPeers()
    }

    public func invitePeer(peerID: MCPeerID, session: MCSession) -> Void {
        serviceBrowser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }
}

extension RemoteParameterServerBrowser : MCNearbyServiceBrowserDelegate {
    // MARK: MCNearbyServiceBrowserDelegate
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        print("found peer: \(peerID) with info: \(String(describing: info))")
        guard peerID != myself.peerID else {
            os_log(.info, "found myself, ignoring")
            return
        }
        DispatchQueue.main.async {
            let server = RemoteParameterReceiver(peerID: peerID)
            let serverName = info?[RemoteParameterAttribute.name]

            let connection = ParameterServer(host: server, name: serverName)
            self.servers.insert(connection)
            self.delegate?.parameterServerBrowser(self, sawServers: Array(self.servers))
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("lost \(peerID)")
        DispatchQueue.main.async {
            let server = self.servers.first(where: { (server) -> Bool in
                server.host.peerID == peerID
            })
            self.servers = self.servers.filter { $0.host.peerID != peerID }
            if let server = server {
                self.delegate?.parameterServerBrowser(self, lostServers: [server])
            }

//            if peerID == self.connectedPeer {
//                if let tweaksViewController = self.tweaksViewController {
//                    tweaksViewController.dismiss(animated: true, completion: nil)
//                    self.tweaksViewController = nil
//                }
//                self.connectedPeer = nil
//                self.session.disconnect()
//            }
        }
    }
}

protocol RemoteParameterServerBrowserDelegate: class {
    func parameterServerBrowser(_ browser: RemoteParameterServerBrowser, sawServers: [ParameterServer])
    func parameterServerBrowser(_ browser: RemoteParameterServerBrowser, lostServers: [ParameterServer])
}
