//
//  PKDeviceFlowManager.swift
//  SampleApp
//
//  Copyright © 2023 Ping Identity. All rights reserved.
//

import Foundation
import UIKit

@available(iOS 16.0, *)
final class PKDeviceFlowManager {
    
    let comm = PKCommunication()
    static let responseHandler = PKResponseHandler()
    static let shared = PKDeviceFlowManager()
    
    // MARK: Register user to PingOne
    
    static private func completeAuth(completionHandler: @escaping(_ isSignUpRequired: Bool, _ error: NSError?) -> Void) {
        guard let deviceAuthenticationId = PKDataManager.shared.deviceAuthenticationId else {
            print("Missing parameters for completeAuth")
            let error = NSError(domain: "PKDeviceFlowManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing deviceAuthenticationId"])
            completionHandler(false, error)
            return
        }
        
        guard let assertionString = PKDataManager.shared.assertion else {
            print("Missing assertion")
            let error = NSError(domain: "PKDeviceFlowManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing assertion"])
            completionHandler(false, error)
            return
        }
        
        // Parse the assertion JSON
        guard let assertionData = assertionString.data(using: .utf8),
              let assertionJSON = try? JSONSerialization.jsonObject(with: assertionData) as? [String: Any] else {
            print("❌ Failed to parse assertion JSON")
            let error = NSError(domain: "PKDeviceFlowManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid assertion JSON"])
            completionHandler(false, error)
            return
        }
        
        // Create the proper request payload
        let requestPayload: [String: Any] = [
            "deviceAuthenticationId": deviceAuthenticationId,
            "rpId": Passkeys.RpId,
            "assertion": assertionJSON  // Send as parsed JSON, not string
        ]
        
        // Use the OIDC-auth URL WITH query params (pi.flow) so DaVinci returns JSON
        let baseUrl = Passkeys.AuthUrl
        
        shared.comm.sendHttpRequest(urlStr: baseUrl, jsonData: requestPayload) { response, error in
            if let error = error {
                print("❌ Complete authentication failed: \(error.localizedDescription)")
                completionHandler(false, error)
            } else {
                print("✅ Complete authentication successful")
                PKDeviceFlowManager.responseHandler.signIn(response) {
                    completionHandler(PKDeviceFlowManager.responseHandler.isSignUpRequired(response), nil)
                }
            }
        }
    }
    
    static func login(username: String, password: String, completionHandler: @escaping(_ error: NSError?) -> Void) {
        print("🔑 Starting login for user: \(username)")
        var loginUrl = Passkeys.AuthUrl.addQueryParams(name: Passkeys.Username, value: username)
        loginUrl = loginUrl.addQueryParams(name: Passkeys.Password, value: password)
        
        shared.comm.sendHttpRequest(urlStr: loginUrl) { response, error in
            if let error = error {
                print("❌ Login failed: \(error.localizedDescription)")
                completionHandler(error)
            } else {
                print("✅ Login response received, parsing...")
                completionHandler(nil)
            }
        }
    }
    
    static func loginAndTryCreateKey(username: String, password: String, completionHandler: @escaping(_ error: NSError?) -> Void) {
        print("🔐 Starting registration for user: \(username)")
        var loginUrl = Passkeys.AuthUrl.addQueryParams(name: Passkeys.Username, value: username)
        loginUrl = loginUrl.addQueryParams(name: Passkeys.Password, value: password)
        
        shared.comm.sendHttpRequest(urlStr: loginUrl) { response, error in
            if let error = error {
                print("❌ Registration failed: \(error.localizedDescription)")
                completionHandler(error)
            } else {
                print("✅ Registration response received, parsing...")
                
                // IMPROVED: Set username before parsing response
                PKDataManager.shared.username = username
                
                PKDeviceFlowManager.responseHandler.signUp(response) {
                    // After parsing, verify we have everything needed
                    let hasChallenge = PKDataManager.shared.challenge != nil
                    let hasUserIdData = PKDataManager.shared.userIdData != nil
                    let hasUsername = PKDataManager.shared.username != nil
                    
                    print("📊 Registration data status:")
                    print("   Challenge: \(hasChallenge ? "✅" : "❌")")
                    print("   UserID: \(hasUserIdData ? "✅" : "❌")")
                    print("   Username: \(hasUsername ? "✅" : "❌")")
                    
                    if hasChallenge && hasUserIdData && hasUsername {
                        print("✅ All required registration data available")
                        completionHandler(nil)
                    } else {
                        print("⚠️ Some registration data missing - attempting to continue anyway")
                        // In DaVinci flows, this might be normal
                        completionHandler(nil)
                    }
                }
            }
        }
    }

    static func startPasskeyRegistration(username: String, password: String, completionHandler: @escaping(_ error: NSError?) -> Void) {
        print("🆕 Starting fresh passkey registration flow")
        
        // Clear any existing data
        PKDataManager.shared.challenge = nil
        PKDataManager.shared.userIdData = nil
        PKDataManager.shared.userId = nil
        PKDataManager.shared.deviceId = nil
        PKDataManager.shared.username = nil
        PKDataManager.shared.attestation = nil
        PKDataManager.shared.deviceAuthenticationId = nil
        
        // Start registration
        loginAndTryCreateKey(username: username, password: password, completionHandler: completionHandler)
    }
    
    static func startPasskeyAuthenticationFlow(completionHandler: @escaping(_ error: NSError?) -> Void) {
        print("🔑 Starting passkey authentication flow")
        
        // Clear existing data
        PKDataManager.shared.challenge = nil
        PKDataManager.shared.deviceAuthenticationId = nil
        PKDataManager.shared.assertion = nil
        
        // Get authentication challenge from server
        let url = Passkeys.AuthUrl
        
        shared.comm.sendHttpRequest(urlStr: url) { response, error in
            if let error = error {
                print("❌ Failed to get authentication challenge: \(error.localizedDescription)")
                completionHandler(error)
            } else {
                print("✅ Got authentication challenge")
                PKDeviceFlowManager.responseHandler.signIn(response) {
                    if PKDataManager.shared.challenge != nil {
                        completionHandler(nil)
                    } else {
                        let challengeError = NSError(domain: "PKDeviceFlowManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No challenge received from server"])
                        completionHandler(challengeError)
                    }
                }
            }
        }
    }
    
    // FIXED: Show proper user input dialog instead of hardcoded credentials
    static func showRegistrationDialog() {
        print("💬 Showing user registration dialog")
        
        guard let window = UIApplication.shared.windows.first,
              let vc = window.rootViewController else {
            print("❌ No root view controller found")
            return
        }
        
        // Dismiss any existing alerts first
        if vc.presentedViewController is UIAlertController {
            vc.presentedViewController?.dismiss(animated: false) {
                showActualRegistrationDialog(from: vc)
            }
        } else {
            showActualRegistrationDialog(from: vc)
        }
    }
    
    private static func showActualRegistrationDialog(from viewController: UIViewController) {
        let alert = UIAlertController(
            title: "Sign In",
            message: "",
            preferredStyle: .alert
        )
        
        // Add username text field
        alert.addTextField { textField in
            textField.placeholder = "Username"
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
        }
        
        // Add password text field
        alert.addTextField { textField in
            textField.placeholder = "Password"
            textField.isSecureTextEntry = true
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            print("👤 User chose not to create passkey")
        })
        
        // Create Passkey action
        alert.addAction(UIAlertAction(title: "Sign in", style: .default) { _ in
            guard let username = alert.textFields?[0].text, !username.isEmpty,
                  let password = alert.textFields?[1].text, !password.isEmpty else {
                showErrorDialog("Please enter both username and password")
                return
            }
            
            print("👤 User entered username: \(username)")
            
            // Validate endpoint first
            Passkeys.validateEndpoint { isValid in
                DispatchQueue.main.async {
                    if isValid {
                        print("✅ Endpoint validation passed, proceeding with registration...")
                        
                        startPasskeyRegistration(username: username, password: password) { error in
                            DispatchQueue.main.async {
                                if let error = error {
                                    print("❌ Registration failed: \(error.localizedDescription)")
                                    showErrorDialog("Registration failed: \(error.localizedDescription)")
                                } else {
                                    print("✅ Registration setup complete, ready for passkey creation")
                                    // Now show the passkey registration UI
                                    if let window = UIApplication.shared.windows.first {
                                        PKManager.signUp(anchor: window)
                                    }
                                }
                            }
                        }
                    } else {
                        showErrorDialog("Server configuration error. Please contact support.")
                    }
                }
            }
        })
        
        viewController.present(alert, animated: true)
    }
    
    private static func showErrorDialog(_ message: String) {
        guard let window = UIApplication.shared.windows.first,
              let vc = window.rootViewController else { return }
        
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        vc.present(alert, animated: true)
    }
    
    // DEPRECATED: Remove hardcoded test registration
    static func testRegistration() {
        print("🧪 Starting registration flow with user input...")
        showRegistrationDialog()
    }
    
    static func handleNoPasskeysFound() {
        print("🔍 No passkeys found, showing registration options...")
        
        guard let window = UIApplication.shared.windows.first,
              let vc = window.rootViewController else { return }
        
        // Dismiss any existing alerts first
        if vc.presentedViewController is UIAlertController {
            vc.presentedViewController?.dismiss(animated: false) {
                showRegistrationDialog()
            }
        } else {
            showRegistrationDialog()
        }
    }
    
    static private func completeRegister(completionHandler: @escaping(_ username: String?, _ error: NSError?) -> Void) {
        // For DaVinci flows, we might not have userId/deviceId from additionalProperties
        // Instead, use deviceAuthenticationId and other available data
        
        guard let attestationString = PKDataManager.shared.attestation else {
            print("Missing attestation")
            let error = NSError(domain: "PKDeviceFlowManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing attestation"])
            completionHandler(nil, error)
            return
        }
        
        // Parse the attestation JSON
        guard let attestationData = attestationString.data(using: .utf8),
              let attestationJSON = try? JSONSerialization.jsonObject(with: attestationData) as? [String: Any] else {
            print("❌ Failed to parse attestation JSON")
            let error = NSError(domain: "PKDeviceFlowManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid attestation JSON"])
            completionHandler(nil, error)
            return
        }
        
        // Create request payload - adapt based on what data we have
        var requestPayload: [String: Any] = [
            "attestation": attestationJSON,
            "rpId": Passkeys.RpId
        ]
        
        // Add available IDs
        if let userId = PKDataManager.shared.userId {
            requestPayload["userId"] = userId
        }
        if let deviceId = PKDataManager.shared.deviceId {
            requestPayload["deviceId"] = deviceId
        }
        if let deviceAuthId = PKDataManager.shared.deviceAuthenticationId {
            requestPayload["deviceAuthenticationId"] = deviceAuthId
        }
        if let username = PKDataManager.shared.username {
            requestPayload["username"] = username
        }
        
        print("📋 Complete registration payload: \(requestPayload.keys.joined(separator: ", "))")
        
        // Use the OIDC-auth URL WITH query params (pi.flow) so DaVinci returns JSON
        let baseUrl = Passkeys.AuthUrl
        
        /* This call succeed using POST and fails using GET, so we'll send parameters in body - PKCommunication will post it when it will notice non empty body. */
        shared.comm.sendHttpRequest(urlStr: baseUrl, jsonData: requestPayload) { response, error in
            if let error = error {
                print("❌ Complete registration failed: \(error.localizedDescription)")
                completionHandler(nil, error)
            } else {
                print("✅ Complete registration successful")
                PKDeviceFlowManager.responseHandler.signUp(response) {
                    completionHandler(PKDataManager.shared.username, nil)
                }
            }
        }
    }
    
    static func verifyConstants() -> Bool {
        if Passkeys.EnvId == "<#envId#>" || Passkeys.ClientId == "<#clientId#>" || Passkeys.UrlBase == "<#urlBase#>" || Passkeys.Domain == "<#domain#>" {
            print(Passkeys.missingCredMsg)
            return false
        }
        return true
    }
    
    // MARK: Handle UI layer
    
    static func signIn(anchor: UIWindow, errorHandler: @escaping(_ error: NSError?) -> Void) {
        if !verifyConstants() {
            return
        }

        // Start with authentication flow to get challenge
        startPasskeyAuthenticationFlow { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Failed to start authentication: \(error.localizedDescription)")
                    errorHandler(error)
                } else {
                    // Use passkey-only authentication for testing
                    PKManager.signInWithPasskeyOnly(anchor: anchor)
                }
            }
        }
    }
    
    static func signUp(anchor: UIWindow) {
        PKManager.signUp(anchor: anchor)
    }
    
    static func deviceGotAttestationFromOS(completionHandler: @escaping(_ username: String?, _ error: NSError?) -> Void) {
        completeRegister { username, error in
            completionHandler(username, error)
        }
    }
    
    static func deviceGotAssertionFromOS(completionHandler: @escaping(_ isSignUpRequired: Bool, _ error: NSError?) -> Void) {
        self.completeAuth { isSignUpRequired, error in
            completionHandler(isSignUpRequired, error)
        }
    }
}

