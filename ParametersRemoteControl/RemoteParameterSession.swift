//
//  RemoteParameterSession.swift
//  Portfolio
//
//  Created by Avi Cieplinski on 9/18/18.
//  Copyright © 2018 Avi Cieplinski. All rights reserved.
//

import MultipeerConnectivity
import UIKit
import os.signpost

// Like the GameSession object in SwiftShot
class RemoteParameterSession: NSObject, MCSessionDelegate {

    let myself: RemoteParameterReceiver
    let session: MCSession
    weak var delegate: RemoteParameterSessionDelegate?

    init(myself: RemoteParameterReceiver) {
        self.myself = myself
        self.session = MCSession(peer: myself.peerID, securityIdentity: nil, encryptionPreference: .optional)

        super.init()
        self.session.delegate = self
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func receive(data: Data, from peerID: MCPeerID) {

    }

    // MARK: MCSessionDelegate
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        print("session with peer: \(peerID) didChange: \(state == .connected)")
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        self.delegate?.session(self, didReceive: data, fromPeer: peerID)
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        print("session with peer: \(peerID) didReceiveStream: \(streamName)")
    }

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        print("session with peer: \(peerID) didStartReceivingResource: \(resourceName)")
    }

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        print("session with peer: \(peerID) didFinishReceivingResourceWithName: \(resourceName)")
    }
}

protocol RemoteParameterSessionDelegate: class {
    func session(_ session: RemoteParameterSession, didReceive data: Data, fromPeer peerID: MCPeerID)
}
