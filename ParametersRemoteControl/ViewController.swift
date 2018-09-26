//
//  ViewController.swift
//  ParametersRemoteControl
//
//  Created by Avi Cieplinski on 9/18/18.
//  Copyright © 2018 Avi Cieplinski. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    var myself: RemoteParameterReceiver? = nil
    var remoteSession: RemoteParameterSession? = nil

    override func viewDidLoad() {
        super.viewDidLoad()

        myself = RemoteParameterReceiver.init(username: "RemoteControl")
        remoteSession = RemoteParameterSession.init(myself: myself!)
    }
}

