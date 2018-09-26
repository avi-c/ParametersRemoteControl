//
//  ParameterServer.swift
//  ParametersRemoteControl
//
//  Created by Avi Cieplinski on 9/18/18.
//  Copyright © 2018 Avi Cieplinski. All rights reserved.
//

import Foundation

struct ParameterServer: Hashable {
    var name: String
    var host: RemoteParameterReceiver

    init(host: RemoteParameterReceiver, name: String? = nil) {
        self.host = host
        self.name = name ?? "\(host.peerID.displayName)"
    }
}
