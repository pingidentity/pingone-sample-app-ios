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
    
    static func authenticate(completionHandler: @escaping(_ error: NSError?) -> Void) {
        if !verifyConstants() { 
            completionHandler(nil)
            return
        }
        let url = Passkeys.AuthUrl
        
        shared.comm.post(urlStr: url) { response, error in
            if let error {
               completionHandler(error)
            } else {
                PKDeviceFlowManager.responseHandler.signIn(response) {
                    completionHandler(nil)
                }
            }
        }
    }
    
    static private func completeAuth(completionHandler: @escaping(_ isSignUpRequired: Bool, _ error: NSError?) -> Void) {
        guard let deviceAuthenticationId = PKDataManager.shared.deviceAuthenticationId else {
            print("Missing parameters for completeAuth")
            return
        }
        guard let assertion = PKDataManager.shared.assertion else {
            print("Missing assertion")
            return
        }
        var authUrl = Passkeys.AuthUrl.addQueryParams(name: Passkeys.DeviceAuthenticationId, value: deviceAuthenticationId)
        authUrl = authUrl.addQueryParams(name: Passkeys.RpIdKey, value: Passkeys.RpId)
        authUrl = authUrl.addQueryParams(name: Passkeys.Assertion, value: assertion)

        shared.comm.post(urlStr: authUrl) { response, error in
            if let error {
                completionHandler(false, error)
            } else {
                PKDeviceFlowManager.responseHandler.signIn(response) {
                    completionHandler(PKDeviceFlowManager.responseHandler.isSignUpRequired(response), nil)
                }
            }
        }
    }
    
    static func register(username: String, password: String, completionHandler: @escaping(_ error: NSError?) -> Void) {
        var registerUrl = Passkeys.AuthUrl.addQueryParams(name: Passkeys.Username, value: username)
        registerUrl = registerUrl.addQueryParams(name: Passkeys.Password, value: password)

        shared.comm.post(urlStr: registerUrl) { response, error in
            if let error {
               completionHandler(error)
            } else {
                PKDeviceFlowManager.responseHandler.signUp(response) {
                    completionHandler(nil)
                }
            }
        }
    }
    
    static private func completeRegister(completionHandler: @escaping(_ username: String?, _ error: NSError?) -> Void) {
        guard let userId = PKDataManager.shared.userId, let deviceId = PKDataManager.shared.deviceId else {
            print("Missing parameters for complete register")
            return
        }
        guard let attestation = PKDataManager.shared.attestation else {
            print("Missing attestation")
            return
        }
        var regUrl = Passkeys.AuthUrl.addQueryParams(name: Passkeys.UserId, value: userId)
        regUrl = regUrl.addQueryParams(name: Passkeys.DeviceId, value: deviceId)
        regUrl = regUrl.addQueryParams(name: Passkeys.Attestation, value: attestation)
        regUrl = regUrl.addQueryParams(name: Passkeys.Origin, value: Passkeys.RpId)
        
        shared.comm.post(urlStr: regUrl) { response, error in
            if let error {
               completionHandler(nil, error)
            } else {
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
    
    static func signIn(anchor: UIWindow) {
        PKManager.signIn(anchor: anchor)
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
