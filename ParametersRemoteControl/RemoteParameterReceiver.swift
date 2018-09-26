//
//  RemoteParameterReceiver.swift
//  Portfolio
//
//  Created by Avi Cieplinski on 9/18/18.
//  Copyright © 2018 Avi Cieplinski. All rights reserved.
//

import MultipeerConnectivity
import simd
import UIKit

// Like the "Player" class in SwiftShot
class RemoteParameterReceiver: Hashable {

    static func == (lhs: RemoteParameterReceiver, rhs: RemoteParameterReceiver) -> Bool {
        return lhs.peerID == rhs.peerID
    }

    func hash(into hasher: inout Hasher) {
        peerID.hash(into: &hasher)
    }

    let peerID: MCPeerID

    init(peerID: MCPeerID) {
        self.peerID = peerID
    }

    init(username: String) {
        self.peerID = MCPeerID(displayName: username)
    }
}
