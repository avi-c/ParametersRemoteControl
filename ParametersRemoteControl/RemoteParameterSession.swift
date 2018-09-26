//
//  RemoteParameterSession.swift
//  Portfolio
//
//  Created by Avi Cieplinski on 9/18/18.
//  Copyright © 2018 Avi Cieplinski. All rights reserved.
//

import MultipeerConnectivity
import SwiftTweaks
import UIKit
import os.signpost

// Like the GameSession object in SwiftShot
class RemoteParameterSession: NSObject, MCSessionDelegate, MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate, TweaksViewControllerDelegate {

    private var tweaksViewController: TweaksViewController? = nil
    private var tweakStore: TweakStore? = nil
    private var connectedPeer: MCPeerID? = nil
    let myself: RemoteParameterReceiver
    private var servers: Set<ParameterServer> = []
    let session: MCSession

    private let serviceAdvertiser: MCNearbyServiceAdvertiser
    private let serviceBrowser : MCNearbyServiceBrowser

    private var multiTweakBindings = Set<MultiTweakBindingIdentifier>()

    init(myself: RemoteParameterReceiver) {
        self.myself = myself
        self.session = MCSession(peer: myself.peerID, securityIdentity: nil, encryptionPreference: .optional)
        let myDevice = UIDevice.current.name
        let descriptionString = "Parameter Receiver: " + myDevice
        let discoveryInfo: [String: String] = ["receiverDescription" : descriptionString]
        serviceAdvertiser = MCNearbyServiceAdvertiser(peer: myself.peerID, discoveryInfo: discoveryInfo, serviceType: RemoteParameterService.serverService)

        serviceBrowser = MCNearbyServiceBrowser(peer: myself.peerID, serviceType: RemoteParameterService.serverService)
        super.init()
        self.session.delegate = self
        serviceAdvertiser.delegate = self
        self.startBrowsing()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func receive(data: Data, from peerID: MCPeerID) {

    }

    func startAdvertising() {
        if #available(iOS 12.0, *) {
            os_log(.info, "ADVERTISING %@", myself.peerID)
        } else {
            print("Advertising \(myself.peerID)")
        }


    }

    func startBrowsing() {
        serviceBrowser.delegate = self
        serviceBrowser.startBrowsingForPeers()
    }

    deinit {
        self.serviceAdvertiser.stopAdvertisingPeer()
        self.serviceBrowser.stopBrowsingForPeers()
    }

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
            self.serviceBrowser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 10)
//            self.delegate?.gameBrowser(self, sawGames: Array(self.servers))
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("lost \(peerID)")
        DispatchQueue.main.async {
            self.servers = self.servers.filter { $0.host.peerID != peerID }

            if peerID == self.connectedPeer {
                if let tweaksViewController = self.tweaksViewController {
                    tweaksViewController.dismiss(animated: true, completion: nil)
                    self.tweaksViewController = nil
                }
                self.connectedPeer = nil
                self.session.disconnect()
            }
        }
    }

    // MARK: MCNearbyServiceAdvertiserDelegate
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        if #available(iOS 12.0, *) {
            os_log(.info, "got request from %@, accepting!", peerID)
        } else {
            print("got request from \(peerID), accepting!")
        }
        invitationHandler(true, session)
    }

    // MARK: MCSessionDelegate
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        print("session with peer: \(peerID) didChange: \(state == .connected)")
    }

    func sendUpdatedTweaks() {

    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            let tweaks = try JSONDecoder().decode(Array<CodeableTweak>.self, from:data)
            print("\(tweaks)")

            if tweakStore == nil, connectedPeer == nil {
                connectedPeer = peerID
                var allTweaks = [TweakClusterType]()

                for tweakData in tweaks {
                    // pull out the values we need an instantiate a Tweak for this
                    let dataType: TweakViewDataType = TweakViewDataType.init(rawValue: tweakData.tweakType)!

                    switch dataType {
                    case .boolean:
                        let newTweak = Tweak(tweakData.collectionName, tweakData.groupName, tweakData.tweakName, tweakData.boolValue)
                        allTweaks.append(newTweak)
                    case .integer:
                        let newTweak = Tweak<Int>(tweakData.collectionName, tweakData.groupName, tweakData.tweakName, tweakData.intValue)
                        allTweaks.append(newTweak)
                    case .cgFloat:
                        let newTweak = Tweak<CGFloat>(tweakData.collectionName, tweakData.groupName, tweakData.tweakName, tweakData.cgFloatValue)
                        allTweaks.append(newTweak)
                    case .double:
                        let newTweak = Tweak<Double>(tweakData.collectionName, tweakData.groupName, tweakData.tweakName, tweakData.doubleValue)
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
                        do {
                            try self.session.send(data, toPeers: self.session.connectedPeers, with: .unreliable)
                        }
                        catch let error {
                            NSLog("%@", "Error for sending: \(error)")
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
                if let window = UIApplication.shared.windows.first {
                    self.tweaksViewController = TweaksViewController(tweakStore: tweakStore, delegate: self)
                    window.rootViewController?.present(self.tweaksViewController!, animated: true, completion: nil)
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

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        print("session with peer: \(peerID) didReceiveStream: \(streamName)")
    }

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        print("session with peer: \(peerID) didStartReceivingResource: \(resourceName)")
    }

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        print("session with peer: \(peerID) didFinishReceivingResourceWithName: \(resourceName)")
    }

    func tweaksViewControllerRequestsDismiss(_ tweaksViewController: TweaksViewController, completion: (() -> ())?) {
        print("dismiss!")
        multiTweakBindings.removeAll()
        self.tweaksViewController?.dismiss(animated: true, completion: completion)
        self.tweaksViewController = nil
        self.connectedPeer = nil
        self.session.disconnect()
    }
}
