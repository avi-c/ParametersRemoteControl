//
//  ParameterServerBrowserViewController.swift
//  ParametersRemoteControl
//
//  Created by Avi Cieplinski on 9/18/18.
//  Copyright © 2018 Avi Cieplinski. All rights reserved.
//

import MultipeerConnectivity
import RemoteParameters
import Parameters
import UIKit

class ParameterServerBrowserViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, RemoteParameterServerBrowserDelegate, RemoteParameterSessionDelegate {

    let observerIdentifier = UUID()
    let tableView: UITableView = UITableView()
    var servers: [ParameterServer] = [ParameterServer]()

    var myself: RemoteParameterReceiver? = nil
    var remoteSession: RemoteParameterSession? = nil
    var remoteServerBrowser: RemoteParameterServerBrowser? = nil

    private var connectedPeer: ParameterServer? = nil
    private var parametersViewController: UINavigationController? = nil

    private var parameterSet: ParameterSet?

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

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ServerCell")

        myself = RemoteParameterReceiver.init(username: "RemoteControl")
        self.remoteSession = RemoteParameterSession.init(myself: self.myself!)
        self.remoteSession?.delegate = self
        self.remoteServerBrowser = RemoteParameterServerBrowser.init(myself: self.myself!)
        self.remoteServerBrowser?.delegate = self
        self.remoteServerBrowser?.startBrowsing()
    }
    
    // MARK UITableViewDataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return servers.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ServerCell", for: indexPath)
        let server = servers[indexPath.row]
        cell.textLabel?.text = server.host.peerID.displayName
        return cell
    }

    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let server = servers[indexPath.row]
        if let remoteSession = self.remoteSession {
            remoteServerBrowser?.invitePeer(peerID: server.host.peerID, session: remoteSession.session)
            self.connectedPeer = server
        }
    }

    func session(_ session: RemoteParameterSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            let decodedParameterSet = try JSONDecoder().decode(ParameterSet.self, from: data)

            // sign up for change observation
            decodedParameterSet.allParameters.forEach { parameter in
                parameter.add(observer: self)
            }

            self.parameterSet = decodedParameterSet
            // show parameters UI
            DispatchQueue.main.async {
                let paramsVC = ParametersViewController()
                paramsVC.parameters = decodedParameterSet.categories
                paramsVC.parametersViewControllerDelegate = self
                paramsVC.title = "Settings"
                paramsVC.navigationItem.rightBarButtonItem = UIBarButtonItem.init(barButtonSystemItem: .done, target: self, action: #selector(self.doneWasTapped))

                let settingsNavigationController = UINavigationController(rootViewController: paramsVC)
                settingsNavigationController.isToolbarHidden = false

                 self.parametersViewController = settingsNavigationController

                // show the parameters view controller

                if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                    appDelegate.navigationController?.present(settingsNavigationController, animated: true, completion: nil)
                }
            }
        } catch {
            print("deserialization error: \(error)")
        }
    }

    @objc private func doneWasTapped() {
        parametersViewController?.dismiss(animated: true, completion: nil)
    }

    func parameterServerBrowser(_ browser: RemoteParameterServerBrowser, sawServers: [ParameterServer]) {
        servers = sawServers
        tableView.reloadData()
    }

    func parameterServerBrowser(_ browser: RemoteParameterServerBrowser, lostServers: [ParameterServer]) {
        for server in lostServers {
            self.servers = self.servers.filter { $0.host.peerID != server.host.peerID }
            if let connectedPeer = self.connectedPeer, connectedPeer.host.peerID == server.host.peerID {
                if let parametersViewController = parametersViewController {
                    parametersViewController.dismiss(animated: true, completion: nil)
                }
            }
        }

        tableView.reloadData()
    }

    func transmitParameters() {
        if let session = remoteSession?.session, let encodedData = try? JSONEncoder().encode(self.parameterSet) {
            do {
                try session.send(encodedData, toPeers: session.connectedPeers, with: .unreliable)
            } catch let error {
                NSLog("%@", "Error for sending: \(error)")
            }
        }
    }
}

extension ParameterServerBrowserViewController: ParameterObserver {
    var identifier: String {
        observerIdentifier.uuidString
    }

    func didUpdate(parameter: Parameter) {
        transmitParameters()
    }
}

extension ParameterServerBrowserViewController: ParametersViewControllerDelegate {
    func willAppear(parametersViewController: ParametersViewController) {
    }

    func didAppear(parametersViewController: ParametersViewController) {
    }

    func willDisappear(parametersViewController: ParametersViewController) {
    }

    func didDisappear(parametersViewController: ParametersViewController) {
        parameterSet?.allParameters.forEach { parameter in
            parameter.remove(observer: self)
        }
        self.parametersViewController = nil
    }
}
