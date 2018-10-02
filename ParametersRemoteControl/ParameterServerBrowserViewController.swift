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

            let allTweaks = self.createTweaksFromDecodedTweaks(decodedTweaks: tweaks)
            self.updateCurrentTweakValues(decodedTweaks: tweaks)

            let multipleBinding = tweakStore?.bindMultiple(allTweaks as! [TweakType]) {
                // for now we'll just send the current state of all the tweaks, not checking which ones have been updated
                if let data = self.tweakStore!.serializeTweaks() {
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

    private func updateCurrentTweakValues(decodedTweaks: [CodeableTweak]) -> Void {
        if let tweakStore = tweakStore {
            for tweakData in decodedTweaks {
                if let matchingTweak = tweakStore.allTweaks.first(where: { (localTweak) -> Bool in
                    return localTweak.tweakName == tweakData.tweakName
                }) {
                    // pull out the values we need an instantiate a Tweak for this
                    let dataType: TweakViewDataType = TweakViewDataType.init(rawValue: tweakData.tweakType)!

                    switch dataType {
                    case .boolean:
                        tweakStore.setValue(tweakData.boolValue, forTweak: matchingTweak)
                    case .integer:
                        tweakStore.setValue(tweakData.intValue, forTweak: matchingTweak)
                    case .cgFloat:
                        tweakStore.setValue(tweakData.cgFloatValue, forTweak: matchingTweak)
                    case .double:
                        tweakStore.setValue(tweakData.doubleValue, forTweak: matchingTweak)
                    case .string:
                        tweakStore.setValue(tweakData.stringValue, forTweak: matchingTweak)
                    default:
                        print("Unsupported tweak type: \(dataType)")
                    }
                }
            }
        }
    }

    private func createTweaksFromDecodedTweaks(decodedTweaks: [CodeableTweak]) -> [TweakClusterType] {
        var allTweaks = [TweakClusterType]()

        if tweakStore == nil {
            for tweakData in decodedTweaks {
                // pull out the values we need and instantiate a Tweak for this
                let dataType: TweakViewDataType = TweakViewDataType.init(rawValue: tweakData.tweakType)!

                switch dataType {
                case .boolean:
                    let newTweak = Tweak(tweakData.collectionName, tweakData.groupName, tweakData.tweakName, tweakData.boolValue)
                    allTweaks.append(newTweak)
                case .integer:
                    let newTweak = Tweak<Int>(tweakData.collectionName, tweakData.groupName, tweakData.tweakName, defaultValue: tweakData.intDefaultValue, min: tweakData.intMinValue, max: tweakData.intMaxValue, stepSize: tweakData.intStepValue)
                    allTweaks.append(newTweak)
                case .cgFloat:
                    let newTweak = Tweak<CGFloat>(tweakData.collectionName, tweakData.groupName, tweakData.tweakName, defaultValue: tweakData.cgFloatDefaultValue, min: tweakData.cgFloatMinValue, max: tweakData.cgFloatMaxValue, stepSize: tweakData.cgFloatStepValue)
                    allTweaks.append(newTweak)
                case .double:
                    let newTweak = Tweak<Double>(tweakData.collectionName, tweakData.groupName, tweakData.tweakName, defaultValue: tweakData.doubleDefaultValue, min: tweakData.doubleMinValue, max: tweakData.doubleMaxValue, stepSize: tweakData.doubleStepValue)
                    allTweaks.append(newTweak)
                case .string:
                    let newTweak = Tweak<String>(tweakData.collectionName, tweakData.groupName, tweakData.tweakName, tweakData.stringValue)
                    allTweaks.append(newTweak)
                default:
                    print("Unsupported tweak type: \(dataType)")
                }
            }

            tweakStore = TweakStore(tweaks: allTweaks, enabled: true)
            self.updateCurrentTweakValues(decodedTweaks: decodedTweaks)
        }

        return allTweaks
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
