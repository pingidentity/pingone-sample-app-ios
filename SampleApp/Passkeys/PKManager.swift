//
//  PKManager.swift
//  SampleApp
//
//  Copyright © 2023 Ping Identity. All rights reserved.
//

import AuthenticationServices
import Foundation
import os

@available(iOS 16.0, *)
class PKManager: NSObject, ASAuthorizationControllerPresentationContextProviding, ASAuthorizationControllerDelegate {
    
    static let shared = PKManager()
    var authenticationAnchor: ASPresentationAnchor?
    private var isRegistrationFlow = false

    static func signUp(anchor: ASPresentationAnchor) {
        print("🔐 Attempting passkey registration...")
        print("Challenge available: \(PKDataManager.shared.challenge != nil)")
        print("UserID available: \(PKDataManager.shared.userIdData != nil)")
        print("Username: \(PKDataManager.shared.username ?? "nil")")

        guard let challenge = PKDataManager.shared.challenge,
              let userId = PKDataManager.shared.userIdData,
              let name = PKDataManager.shared.username else {
            print("❌ No challenge or userId from server")
            return
        }

        shared.authenticationAnchor = anchor
        shared.isRegistrationFlow = true
        let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: Passkeys.Domain)

        let registrationRequest = if Passkeys.isAutoEnrollmentEnabled {
            if #available(iOS 18.0, *) {
                publicKeyCredentialProvider.createCredentialRegistrationRequest(challenge: challenge, name: name, userID: userId, requestStyle: .conditional)
            } else {
                fatalError("Automatic Enrollment is supported on iOS 18 and above")
            }
        } else {
            publicKeyCredentialProvider.createCredentialRegistrationRequest(challenge: challenge, name: name, userID: userId)
        }

        let authController = ASAuthorizationController(authorizationRequests: [ registrationRequest ] )
        authController.delegate = shared
        authController.presentationContextProvider = shared

        print("🚀 Performing passkey registration request...")
        authController.performRequests()
    }
    
    static func signIn(anchor: ASPresentationAnchor) {
        guard let challenge = PKDataManager.shared.challenge else {
            print("No challenge from server")
            return
        }
        shared.authenticationAnchor = anchor
        shared.isRegistrationFlow = false
        let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: Passkeys.Domain)

        let assertionRequest = publicKeyCredentialProvider.createCredentialAssertionRequest(challenge: challenge)

        // IMPORTANT: Only request passkey authentication, remove password fallback for now
        let authController = ASAuthorizationController(authorizationRequests: [assertionRequest])
        authController.delegate = shared
        authController.presentationContextProvider = shared
        
        // Change from .preferImmediatelyAvailableCredentials to standard performRequests()
        // This will show passkey UI even if no credentials are immediately available
        authController.performRequests()
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        let logger = Logger()
        
        switch authorization.credential {
        case let credentialRegistration as ASAuthorizationPlatformPublicKeyCredentialRegistration:
            print("✅ PASSKEY REGISTRATION SUCCESS")
            logger.log("A new passkey was registered: \(credentialRegistration)")

            guard let attestationObject = credentialRegistration.rawAttestationObject else {
                print("Missing attestationObject")
                return
            }
            let clientDataJSON = credentialRegistration.rawClientDataJSON
            let credentialID = credentialRegistration.credentialID
            
            // Correct WebAuthn attestation structure
            let payload = [
                "rawId": credentialID.base64EncodedString(),
                "id": credentialRegistration.credentialID.base64URLEncode(),
                "type": "public-key",
                "response": [
                    "attestationObject": attestationObject.base64EncodedString(),
                    "clientDataJSON": clientDataJSON.base64EncodedString()
                ]
            ] as [String: Any]
            
            if let payloadJSONData = try? JSONSerialization.data(withJSONObject: payload, options: []) {
                guard let payloadJSONText = String(data: payloadJSONData, encoding: .utf8) else { return }
                PKDataManager.shared.attestation = payloadJSONText
                print("📋 Attestation payload created: \(payloadJSONText)")
            }
            
            didFinishSignUp()

        case let credentialAssertion as ASAuthorizationPlatformPublicKeyCredentialAssertion:
            print("✅ PASSKEY AUTHENTICATION SUCCESS")
            logger.log("A passkey was used to sign in: \(credentialAssertion)")

            // Grab the WebAuthn user handle (opaque bytes) from the assertion
            guard let userID = credentialAssertion.userID else {
                print("Missing userID")
                return
            }

            // Persist it for later flows (e.g., registration chaining, debugging)
            PKDataManager.shared.userIdData = userID
            if let decoded = String(data: userID, encoding: .utf8), !decoded.isEmpty {
                PKDataManager.shared.username = decoded
                print("✅ Extracted username from userHandle: \(decoded)")
            }

            guard let signature = credentialAssertion.signature else {
                print("Missing signature")
                return
            }
            guard let authenticatorData = credentialAssertion.rawAuthenticatorData else {
                print("Missing authenticatorData")
                return
            }

            let clientDataJSON = credentialAssertion.rawClientDataJSON
            let credentialId = credentialAssertion.credentialID

            // Correct WebAuthn assertion structure
            let payload: [String: Any] = [
                "rawId": credentialId.base64URLEncode(),
                "id": credentialId.base64URLEncode(),
                "type": "public-key",
                "response": [
                    "clientDataJSON": clientDataJSON.base64EncodedString(),
                    "authenticatorData": authenticatorData.base64EncodedString(),
                    "signature": signature.base64EncodedString(),
                    "userHandle": userID.base64URLEncode()
                ]
            ]

            if let payloadJSONData = try? JSONSerialization.data(withJSONObject: payload, options: []),
               let payloadJSONText = String(data: payloadJSONData, encoding: .utf8) {
                PKDataManager.shared.assertion = payloadJSONText
                print("📋 Assertion payload created: \(payloadJSONText)")
            }

            didFinishSignIn()

        case let passwordCredential as ASPasswordCredential:
            print("⚠️ PASSWORD AUTHENTICATION (NOT PASSKEY)")
            logger.log("A password was provided: \(passwordCredential)")

            // Handle password authentication if you want to support it
            let userName = passwordCredential.user
            let password = passwordCredential.password
            print("Username: \(userName)")
            // You could send this to your server for password verification

        default:
            print("❌ UNKNOWN AUTHENTICATION TYPE")
            fatalError("Received unknown authorization type.")
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let logger = Logger()
        guard let authorizationError = error as? ASAuthorizationError else {
            logger.error("Unexpected authorization error: \(error.localizedDescription)")
            return
        }

        switch authorizationError.code {
        case .canceled:
            logger.log("Request canceled - no passkeys found, user canceled, or domain issue")

            if !isRegistrationFlow {
                // Authentication was canceled - likely no passkeys available
                print("🔄 Authentication canceled, attempting registration flow...")
                handleAuthenticationFailure()
            } else {
                // Registration was canceled by user
                print("👤 User canceled registration")
                // Don't show another dialog if user explicitly canceled
                print("💡 User can try registration again from the main interface")
            }

        case .invalidResponse:
            logger.error("Invalid response from authenticator")
            showErrorAlert("Invalid response from authenticator")

        case .notHandled:
            logger.error("Request not handled - possible domain configuration issue")
            showErrorAlert("Request not handled - check domain configuration")

        case .failed:
            logger.error("Authentication failed: \(authorizationError.localizedDescription)")
            showErrorAlert("Authentication failed: \(authorizationError.localizedDescription)")

        default:
            logger.error("Error: \((error as NSError).userInfo)")
            showErrorAlert("Unknown error occurred")
        }
    }

    private func handleAuthenticationFailure() {
        print("🔍 Handling authentication failure...")

        // Clear any existing authentication data
        PKDataManager.shared.challenge = nil
        PKDataManager.shared.deviceAuthenticationId = nil

        DispatchQueue.main.async {
            // Use the new dialog system instead of hardcoded registration
            PKDeviceFlowManager.handleNoPasskeysFound()
        }
    }

    private func showErrorAlert(_ message: String) {
        guard let vc = authenticationAnchor?.rootViewController else { return }

        // Make sure we don't stack alerts
        if vc.presentedViewController is UIAlertController {
            vc.presentedViewController?.dismiss(animated: false) {
                self.presentErrorAlert(vc, message)
            }
        } else {
            presentErrorAlert(vc, message)
        }
    }

    private func presentErrorAlert(_ vc: UIViewController, _ message: String) {
        let alert = UIAlertController(
            title: "Passkey Error",
            message: message,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "OK", style: .default))
        vc.present(alert, animated: true)
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return authenticationAnchor!
    }

    func didFinishSignIn() {
        print("🎉 Passkey authentication completed locally")
        // Try to extract username from various possible locations
        let username = PKDataManager.shared.username ?? "Unknown User"
        print("✅ Authentication successful for user: \(username)")
        NotificationCenter.default.post(name: .UserSignedIn, object: ["username": username])
    }

    func needSignUp() {
        NotificationCenter.default.post(name: .UserNeedSignUp, object: nil)
    }
    
    func didFinishSignUp() {
        print("🎉 Passkey registration completed locally")
        NotificationCenter.default.post(name: .UserSignedUp, object: nil)
    }

    static func signInWithPasskeyOnly(anchor: ASPresentationAnchor) {
        guard let challenge = PKDataManager.shared.challenge else {
            print("No challenge from server")
            return
        }

        shared.authenticationAnchor = anchor
        shared.isRegistrationFlow = false
        let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: Passkeys.Domain)

        let assertionRequest = publicKeyCredentialProvider.createCredentialAssertionRequest(challenge: challenge)

        // Only request passkey authentication - no password fallback
        let authController = ASAuthorizationController(authorizationRequests: [assertionRequest])
        authController.delegate = shared
        authController.presentationContextProvider = shared

        print("🔐 Requesting passkey authentication only")
        authController.performRequests(options: .preferImmediatelyAvailableCredentials)
    }

    static func signInWithBothOptions(anchor: ASPresentationAnchor) {
        guard let challenge = PKDataManager.shared.challenge else {
            print("No challenge from server")
            return
        }

        shared.authenticationAnchor = anchor
        shared.isRegistrationFlow = false
        let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: Passkeys.Domain)
        let passwordCredentialProvider = ASAuthorizationPasswordProvider()

        let assertionRequest = publicKeyCredentialProvider.createCredentialAssertionRequest(challenge: challenge)
        let passwordRequest = passwordCredentialProvider.createRequest()

        let authController = ASAuthorizationController(authorizationRequests: [assertionRequest, passwordRequest])
        authController.delegate = shared
        authController.presentationContextProvider = shared

        print("🔐 Requesting both passkey and password authentication")
        // Try immediate credentials first, fall back to full UI if needed
        authController.performRequests(options: .preferImmediatelyAvailableCredentials)
    }
}
