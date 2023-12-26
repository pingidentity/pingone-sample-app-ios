//
//  PKResponseHandler.swift
//  SampleApp
//
//  Copyright © 2023 Ping Identity. All rights reserved.
//

import Foundation


class PKResponseHandler {
    
    func signIn(_ response: [String: Any]?, completionHandler: @escaping() -> Void) {
        guard let signInData = try? JSONSerialization.data(withJSONObject: response ?? [:], options: []) else {
            print("Error parsing completeSignIn data")
            completionHandler()
            return
        }
        var signInResponse: SignInResponse
        do {
            signInResponse = try JSONDecoder().decode(SignInResponse.self, from: signInData)
        } catch _ as NSError {
            print("Error decoding completeSignIn data")
            completionHandler()
            return
        }
        // auth
        if let additionalProperties = signInResponse.additionalProperties, let options = additionalProperties.publicKeyCredentialRequestOptions {
            do {
                if let json = options.data(using: String.Encoding.utf8) {
                    if let jsonData = try JSONSerialization.jsonObject(with: json, options: .allowFragments) as? [String: AnyObject] {
                        if let challengeIntArray = jsonData["challenge"] as? [Int] {
                            var arrInt8 = [UInt8]()
                            for num in challengeIntArray {
                                let unsigned = UInt8(bitPattern: Int8(num))
                                arrInt8.append(unsigned)
                            }
                            PKDataManager.shared.challenge = Data(arrInt8)
                        }
                    }
                }
            } catch {
                print(error.localizedDescription)
                completionHandler()
            }
            if let deviceAuthId = additionalProperties.deviceAuthenticationId {
                PKDataManager.shared.deviceAuthenticationId = deviceAuthId
            }
            if let username = additionalProperties.username {
                PKDataManager.shared.username = username
            }
        }
        
        // Complete auth
        if let additionalProperties = signInResponse.additionalProperties, let username = additionalProperties.username {
            PKDataManager.shared.username = username
        }

        completionHandler()
    }
    
    func isSignUpRequired(_ response: [String: Any]?) -> Bool {
        if let httpBody = response?["httpBody"] as? [String: Any], let error = httpBody["error"] as? [String: Any] {
            if let httpResponseCode = error["httpResponseCode"] as? Int {
                if let errorDetails = error["details"] as? [[String: Any]], let rawResponse = errorDetails.first?["rawResponse"] as? [String: Any], let code = rawResponse["code"] as? String {
                    if httpResponseCode == 400 && code == "NOT_FOUND" {
                        return true
                    }
                }
            }
        }
        return false
    }
    
    func signUp(_ response: [String: Any]?, completionHandler: @escaping() -> Void) {
        guard let signUpData = try? JSONSerialization.data(withJSONObject: response ?? [:], options: []) else {
            print("Error parsing completeSignUp data")
            completionHandler()
            return
        }
        var signUpResponse: SignUpResponse
        do {
            signUpResponse = try JSONDecoder().decode(SignUpResponse.self, from: signUpData)
        } catch _ as NSError {
            print("Error decoding completeSignUp data")
            completionHandler()
            return
        }
        if let additionalProperties = signUpResponse.additionalProperties, let options = additionalProperties.publicKeyCredentialCreationOptions {
            do {
                if let json = options.data(using: String.Encoding.utf8) {
                    if let jsonData = try JSONSerialization.jsonObject(with: json, options: .allowFragments) as? [String: AnyObject] {
                        if let challengeIntArray = jsonData["challenge"] as? [Int] {
                            var arrInt8 = [UInt8]()
                            for num in challengeIntArray {
                                let unsigned = UInt8(bitPattern: Int8(num))
                                arrInt8.append(unsigned)
                            }
                            PKDataManager.shared.challenge = Data(arrInt8)
                        }
                        if let user = jsonData["user"] as? [String: Any], let idIntArray = user["id"] as? [Int] {
                            var arrInt8 = [UInt8]()
                            for num in idIntArray {
                                let unsigned = UInt8(bitPattern: Int8(num))
                                arrInt8.append(unsigned)
                            }
                            PKDataManager.shared.userIdData = Data(arrInt8)
                        }
                    }
                }
            } catch {
                print(error.localizedDescription)
                completionHandler()
            }
            
            if let userId = additionalProperties.userId, let deviceId = additionalProperties.deviceId {
                PKDataManager.shared.userId = userId
                PKDataManager.shared.deviceId = deviceId
            }
        }
        if let parameters = signUpResponse.parameters, let authorizationRequest = parameters.authorizationRequest, let username = authorizationRequest.username {
            PKDataManager.shared.username = username
        }
        completionHandler()
    }
}
