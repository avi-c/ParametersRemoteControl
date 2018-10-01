//
//  ParameterServerBrowserViewController.swift
//  ParametersRemoteControl
//
//  Created by Avi Cieplinski on 9/18/18.
//  Copyright © 2018 Avi Cieplinski. All rights reserved.
//

import UIKit

class ParameterServerBrowserViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    let tableView: UITableView = UITableView()
    var receivers: [RemoteParameterReceiver] = [RemoteParameterReceiver]()

    var myself: RemoteParameterReceiver? = nil
    var remoteSession: RemoteParameterSession? = nil

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(tableView)

        self.view.backgroundColor = UIColor.lightGray

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.widthAnchor.constraint(equalTo: self.view.widthAnchor).isActive = true
        tableView.heightAnchor.constraint(equalTo: self.view.heightAnchor).isActive = true
        tableView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        tableView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor).isActive = true

        tableView.dataSource = self
        tableView.delegate = self
        tableView.layer.cornerRadius = 10
        tableView.clipsToBounds = true

        myself = RemoteParameterReceiver.init(username: "RemoteControl")
        self.remoteSession = RemoteParameterSession.init(myself: self.myself!)
    }
    
    // MARK UITableViewDataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return receivers.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ServerCell", for: indexPath)
        let receiver = receivers[indexPath.row]
        cell.textLabel?.text = receiver.peerID.displayName
        return cell
    }

    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let receiver = receivers[indexPath.row]
        //            joinGame(otherPlayer)
    }
}
