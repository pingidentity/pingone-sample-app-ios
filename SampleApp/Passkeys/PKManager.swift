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
    
    static func signUp(anchor: ASPresentationAnchor) {
        guard let challenge = PKDataManager.shared.challenge, let userId = PKDataManager.shared.userIdData, let name = PKDataManager.shared.username else {
            print("No challenge or userId from server")
            return
        }
        shared.authenticationAnchor = anchor
        let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: Passkeys.Domain)

        // Fetch the challenge from the server. The challenge needs to be unique for each request.
        // The userID is the identifier for the user's account.
        
        let registrationRequest = publicKeyCredentialProvider.createCredentialRegistrationRequest(challenge: challenge, name: name, userID: userId)

        // Use only ASAuthorizationPlatformPublicKeyCredentialRegistrationRequests or
        // ASAuthorizationSecurityKeyPublicKeyCredentialRegistrationRequests here.
        let authController = ASAuthorizationController(authorizationRequests: [ registrationRequest ] )
        authController.delegate = shared
        authController.presentationContextProvider = shared
        authController.performRequests()
    }
    
    static func signIn(anchor: ASPresentationAnchor) {
        guard let challenge = PKDataManager.shared.challenge else {
            print("No challenge from server")
            return
        }
        shared.authenticationAnchor = anchor
        let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: Passkeys.Domain)

        let assertionRequest = publicKeyCredentialProvider.createCredentialAssertionRequest(challenge: challenge)

        // Also allow the user to use a saved password, if they have one.
        let passwordCredentialProvider = ASAuthorizationPasswordProvider()
        let passwordRequest = passwordCredentialProvider.createRequest()

        // Pass in any mix of supported sign-in request types.
        let authController = ASAuthorizationController(authorizationRequests: [ assertionRequest, passwordRequest ] )
        authController.delegate = shared
        authController.presentationContextProvider = shared
        
        // If credentials are available, presents a modal sign-in sheet.
        // If there are no locally saved credentials, no UI appears and
        // the system passes ASAuthorizationError.Code.canceled to call
        // `AccountManager.authorizationController(controller:didCompleteWithError:)`.
        authController.performRequests(options: .preferImmediatelyAvailableCredentials)
        
        /*
        // If credentials are available, presents a modal sign-in sheet.
        // If there are no locally saved credentials, the system presents a QR code to allow signing in with a
        // passkey from a nearby device.
        authController.performRequests()
         */
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        let logger = Logger()
        
        switch authorization.credential {
        case let credentialRegistration as ASAuthorizationPlatformPublicKeyCredentialRegistration:
            logger.log("A new passkey was registered: \(credentialRegistration)")
            // Verify the attestationObject and clientDataJSON with your service.
            // The attestationObject contains the user's new public key to store and use for subsequent sign-ins.
            guard let attestationObject = credentialRegistration.rawAttestationObject else {
                print("Missing attestationObject")
                return
            }
            let clientDataJSON = credentialRegistration.rawClientDataJSON
            let credentialID = credentialRegistration.credentialID
            
            // After the server verifies the registration and creates the user account, sign in the user with the new account.
            // Build the attestation object
            let payload = ["rawId": credentialID.base64EncodedString(), // Base64
                           "id": credentialRegistration.credentialID.base64URLEncode(), // Base64URL
                           // "authenticatorAttachment": "platform", // Optional
                           // "clientExtensionResults": [String: Any](), // Optional
                           "type": "public-key",
                               "response": [
                                "attestationObject": attestationObject.base64EncodedString(),
                                "clientDataJSON": clientDataJSON.base64EncodedString()
                               ]
            ] as [String: Any]
            
            if let payloadJSONData = try? JSONSerialization.data(withJSONObject: payload, options: .fragmentsAllowed) {
                guard let payloadJSONText = String(data: payloadJSONData, encoding: .utf8) else { return }
                PKDataManager.shared.attestation = payloadJSONText
            }
            
            didFinishSignUp()
        case let credentialAssertion as ASAuthorizationPlatformPublicKeyCredentialAssertion:
            logger.log("A passkey was used to sign in: \(credentialAssertion)")
            // Verify the below signature and clientDataJSON with your service for the given userID.
            guard let signature = credentialAssertion.signature else {
                print("Missing signature")
                return
            }
            guard let authenticatorData = credentialAssertion.rawAuthenticatorData else {
                print("Missing authenticatorData")
                return
            }
            guard let userID = credentialAssertion.userID else {
                print("Missing userID")
                return
            }
            let clientDataJSON = credentialAssertion.rawClientDataJSON
            let credentialId = credentialAssertion.credentialID
        
            let payload = ["rawId": credentialId.base64EncodedString(), // Base64
                           "id": credentialId.base64URLEncode(), // Base64URL
                           // "authenticatorAttachment": "platform", // Optional
                           // "clientExtensionResults": [String: Any](), // Optional
                           "type": "public-key",
                               "response": [
                                "clientDataJSON": clientDataJSON.base64EncodedString(),
                                "authenticatorData": authenticatorData.base64EncodedString(),
                                "signature": signature.base64EncodedString(),
                                "userHandle": userID.base64URLEncode()
                               ]
            ] as [String: Any]
            
            if let payloadJSONData = try? JSONSerialization.data(withJSONObject: payload, options: .fragmentsAllowed) {
                guard let payloadJSONText = String(data: payloadJSONData, encoding: .utf8) else { return }
                PKDataManager.shared.assertion = payloadJSONText
            }
 
            didFinishSignIn()
        case let passwordCredential as ASPasswordCredential:
            logger.log("A password was provided: \(passwordCredential)")
            // Verify the userName and password with your service.
            // let userName = passwordCredential.user
            // let password = passwordCredential.password
            // After the server verifies the userName and password, sign in the user.
            print("After the server verifies the userName and password (not passkeys), sign in the user.")

        default:
            fatalError("Received unknown authorization type.")
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let logger = Logger()
        guard let authorizationError = error as? ASAuthorizationError else {
            logger.error("Unexpected authorization error: \(error.localizedDescription)")
            return
        }

        if authorizationError.code == .canceled {
            // Either the system doesn't find any credentials and the request ends silently, or the user cancels the request.
            // This is a good time to show a traditional login form, or ask the user to create an account.
            logger.log("Request canceled.")
        
            // Assuming no credentials found, trying to register
            needSignUp()
        } else {
            // Another ASAuthorization error.
            // Note: The userInfo dictionary contains useful information.
            logger.error("Error: \((error as NSError).userInfo)")
        }
        if let vc = PKManager.shared.authenticationAnchor?.rootViewController {
            Alert.generic(viewController: vc, message: nil, error: error as NSError)
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return authenticationAnchor!
    }

    func didFinishSignIn() {
        NotificationCenter.default.post(name: .UserSignedIn, object: nil)
    }
    func needSignUp() {
        NotificationCenter.default.post(name: .UserNeedSignUp, object: nil)
    }
    
    func didFinishSignUp() {
        NotificationCenter.default.post(name: .UserSignedUp, object: nil)
    }
}
