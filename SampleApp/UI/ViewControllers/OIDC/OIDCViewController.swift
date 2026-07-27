//
//  OIDCViewController.swift
//  SampleApp
//
//  Created by Ping Identity on 10/10/19.
//  Copyright © 2019 Ping Identity. All rights reserved.
//

import UIKit
import AppAuth
import PingOneSDK

class OIDCViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = PairingMethodName.OIDC
    }

    @IBAction func pairDevice(_ sender: UIButton) {
        
        guard let issuer = URL(string: OIDC.Issuer) else {
            print("Error creating URL for: \(OIDC.Issuer)")
            return
        }
        OIDAuthorizationService.discoverConfiguration(forIssuer: issuer) { configuration, error in

            guard let config = configuration else {
                print("Error retrieving discovery document: \(error?.localizedDescription ?? "DEFAULT_ERROR")")
                return
            }

            print("Got configuration: \(config)")
            self.doAuthWithAutoCodeExchange(configuration: config, clientID: OIDC.ClientID, clientSecret: nil)
        }
    }
    
    func doAuthWithAutoCodeExchange(configuration: OIDServiceConfiguration, clientID: String, clientSecret: String?) {

        guard let redirectURI = URL(string: OIDC.RedirectURI) else {
            print("Error creating URL for: \(OIDC.RedirectURI)")
            return
        }
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let payload = try await PingOne.generateMobilePayload()
                let request = OIDAuthorizationRequest(configuration: configuration, clientId: clientID, clientSecret: clientSecret, scopes: [OIDScopeOpenID, OIDScopeProfile], redirectURL: redirectURI, responseType: OIDResponseTypeCode, additionalParameters: [OIDCKey.MobilePayload: payload, OIDCKey.PromptKey: OIDCKey.PromptValue])
                
                print("Initiating authorization request with scope: \(request.scope ?? "DEFAULT_SCOPE")")
                await MainActor.run {
                    self.appAuthRequest(With: request)
                }
            } catch {
                await MainActor.run {
                    Alert.generic(viewController: self, message: nil, error: error as NSError)
                }
            }
        }
    }
    
    func appAuthRequest(With request: OIDAuthorizationRequest) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            print("Error accessing AppDelegate")
            return
        }
        appDelegate.currentAuthorizationFlow = OIDAuthState.authState(byPresenting: request, presenting: self) { authState, error in

            if let authState = authState, let idToken = authState.lastTokenResponse?.idToken {
                // Show idToken
                print("Got authorization tokens. Access token: \(authState.lastTokenResponse?.accessToken ?? "DEFAULT_TOKEN")")
                
                DispatchQueue.main.async {
                    let pairAlert = UIAlertController(title: Local.Success, message: Local.AuthCompleted, preferredStyle: .alert)
                    pairAlert.addAction(UIKit.UIAlertAction(title: Local.Ok, style: .cancel, handler: { (action) in
                        self.processIdToken(idToken)
                    }))
                    self.present(pairAlert, animated: true)
                }

            } else {
                print("Authorization error: \(error?.localizedDescription ?? "DEFAULT_ERROR")")
                Alert.generic(viewController: self, message: "Authorization error", error: error as NSError?)
                UIPasteboard.general.string = "\(error?.localizedDescription ?? "DEFAULT_ERROR")"
            }
        }
    }

    func processIdToken(_ idToken: String) {
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let pairingObject = try await PingOne.processIdToken(idToken)
                await MainActor.run {
                    if let pairingObject = pairingObject {
                        self.displayNotificationViewAlert(pairingObject)
                    }
                }
            } catch {
                await MainActor.run {
                    print(error.localizedDescription)
                }
            }
        }
    }
    
    func displayNotificationViewAlert(_ pairingObject: PairingObject) {
        Alert.approveDeny(viewController: self, title: Local.Pair) { (approved) in
            if let approved = approved {
                if approved {
                    Task { [weak self] in
                        guard let self = self else { return }
                        do {
                            let _ = try await pairingObject.approve()
                            await MainActor.run {
                                Alert.generic(viewController: self, message: Local.DeviceIsPaired, error: nil)
                            }
                        } catch {
                            await MainActor.run {
                                Alert.generic(viewController: self, message: nil, error: error as NSError)
                            }
                        }
                    }
                }
            }
        }
    }
}
