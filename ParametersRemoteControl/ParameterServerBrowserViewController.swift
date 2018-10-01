//
//  ParameterServerBrowserViewController.swift
//  ParametersRemoteControl
//
//  Created by Avi Cieplinski on 9/18/18.
//  Copyright © 2018 Avi Cieplinski. All rights reserved.
//

import MultipeerConnectivity
import SwiftTweaks
import UIKit

class ParameterServerBrowserViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, RemoteParameterServerBrowserDelegate, RemoteParameterSessionDelegate, TweaksViewControllerDelegate {

    let tableView: UITableView = UITableView()
    var servers: [ParameterServer] = [ParameterServer]()

    var myself: RemoteParameterReceiver? = nil
    var remoteSession: RemoteParameterSession? = nil
    var remoteServerBrowser: RemoteParameterServerBrowser? = nil

    private var connectedPeer: ParameterServer? = nil
    private var tweaksViewController: TweaksViewController? = nil
    private var tweakStore: TweakStore? = nil
    private var multiTweakBindings = Set<MultiTweakBindingIdentifier>()

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
            let tweaks = try JSONDecoder().decode(Array<CodeableTweak>.self, from:data)
            print("\(tweaks)")

            if tweakStore == nil {
                var allTweaks = [TweakClusterType]()

                for tweakData in tweaks {
                    // pull out the values we need an instantiate a Tweak for this
                    let dataType: TweakViewDataType = TweakViewDataType.init(rawValue: tweakData.tweakType)!

                    switch dataType {
                    case .boolean:
                        let newTweak = Tweak(tweakData.collectionName, tweakData.groupName, tweakData.tweakName, tweakData.boolValue)
                        allTweaks.append(newTweak)
                    case .integer:
                        let newTweak = Tweak<Int>(tweakData.collectionName, tweakData.groupName, tweakData.tweakName, defaultValue: tweakData.intValue, min: tweakData.intMinValue, max: tweakData.intMaxValue, stepSize: tweakData.intStepValue)
                        allTweaks.append(newTweak)
                    case .cgFloat:
                        let newTweak = Tweak<CGFloat>(tweakData.collectionName, tweakData.groupName, tweakData.tweakName, defaultValue: tweakData.cgFloatValue, min: tweakData.cgFloatMinValue, max: tweakData.cgFloatMaxValue, stepSize: tweakData.cgFloatStepValue)
                        allTweaks.append(newTweak)
                    case .double:
                        let newTweak = Tweak<Double>(tweakData.collectionName, tweakData.groupName, tweakData.tweakName, defaultValue: tweakData.doubleValue, min: tweakData.doubleMinValue, max: tweakData.doubleMaxValue, stepSize: tweakData.doubleStepValue)
                        allTweaks.append(newTweak)
                    case .string:
                        let newTweak = Tweak<String>(tweakData.collectionName, tweakData.groupName, tweakData.tweakName, tweakData.stringValue)
                        allTweaks.append(newTweak)
                    default:
                        print("Unsupported tweak type: \(dataType)")
                    }
                }
                tweakStore = TweakStore(tweaks: allTweaks, enabled: true)

                let multipleBinding = tweakStore?.bindMultiple(allTweaks as! [TweakType]) {
                    // for now we'll just send the current state of all the tweaks, not checking which ones have been updated
                    let array = Array(self.tweakStore!.allTweaks)
                    if let data = self.serializeTweaks(tweaks: array) {
                        print("\(data.count)")
                        // transmit data
                        if let connectedPeer = self.connectedPeer {
                            do {
                                try self.remoteSession?.session.send(data, toPeers: [connectedPeer.host.peerID], with: .unreliable)
                            }
                            catch let error {
                                NSLog("%@", "Error for sending: \(error)")
                            }
                        }
                    }
                }
                multiTweakBindings.insert(multipleBinding!)
            }
        } catch {
            print("deserialization error: \(error)")
        }

        if let tweakStore = tweakStore {
            // show parameters UI
            DispatchQueue.main.async {
                if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                    self.tweaksViewController = TweaksViewController(tweakStore: tweakStore, delegate: self)
                    appDelegate.navigationController?.present(self.tweaksViewController!, animated: true, completion: nil)
                }
            }
        }
    }

    private func serializeTweaks(tweaks: [AnyTweak]) -> Data? {
        guard let tweakStore = tweakStore else { return nil }
        var tweakInfo = [CodeableTweak]()

        for tweak in tweaks {
            var codedTweak = CodeableTweak(tweak: tweak)
            if tweak.tweakViewDataType == .cgFloat {
                let tweakInstance = tweak.tweak as! Tweak<CGFloat>
                codedTweak.cgFloatValue = tweakStore.assign(tweakInstance)
            } else if tweak.tweakViewDataType == .double {
                let tweakInstance = tweak.tweak as! Tweak<Double>
                codedTweak.doubleValue = tweakStore.assign(tweakInstance)
            } else if tweak.tweakViewDataType == .integer {
                let tweakInstance = tweak.tweak as! Tweak<Int>
                codedTweak.intValue = tweakStore.assign(tweakInstance)
            } else if tweak.tweakViewDataType == .boolean {
                let tweakInstance = tweak.tweak as! Tweak<Bool>
                codedTweak.boolValue = tweakStore.assign(tweakInstance)
            } else if tweak.tweakViewDataType == .string {
                let tweakInstance = tweak.tweak as! Tweak<String>
                codedTweak.stringValue = tweakStore.assign(tweakInstance)
            }
            tweakInfo.append(codedTweak)
        }

        let encodedData = try? JSONEncoder().encode(tweakInfo)

        return encodedData
    }

    func parameterServerBrowser(_ browser: RemoteParameterServerBrowser, sawServers: [ParameterServer]) {
        servers = sawServers
        tableView.reloadData()
    }

    func parameterServerBrowser(_ browser: RemoteParameterServerBrowser, lostServers: [ParameterServer]) {
        for server in lostServers {
            self.servers = self.servers.filter { $0.host.peerID != server.host.peerID }
            if let connectedPeer = self.connectedPeer, let tweaksViewController = self.tweaksViewController {
                if connectedPeer.host.peerID == server.host.peerID {
                    tweaksViewController.dismiss(animated: true, completion: nil)
                }
            }
        }

        tableView.reloadData()
    }

    func tweaksViewControllerRequestsDismiss(_ tweaksViewController: TweaksViewController, completion: (() -> ())?) {
        multiTweakBindings.removeAll()
        self.tweaksViewController?.dismiss(animated: true, completion: nil)
        self.tweaksViewController = nil
        self.connectedPeer = nil
        self.remoteSession?.session.disconnect()
    }
}
