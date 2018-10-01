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
    var remoteServerBrowser: RemoteParameterServerBrowser? = nil
    var browserViewController: ParameterServerBrowserViewController = ParameterServerBrowserViewController()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.brown
        myself = RemoteParameterReceiver.init(username: "RemoteControl")
        self.navigationController?.pushViewController(self.browserViewController, animated: false)
        self.remoteSession = RemoteParameterSession.init(myself: self.myself!)
        self.remoteServerBrowser = RemoteParameterServerBrowser.init(myself: self.myself!)
        self.remoteServerBrowser?.startBrowsing()
    }
}

