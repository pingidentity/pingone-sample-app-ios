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
            completionHandler(); return
        }

        var signInResponse: SignInResponse
        do {
            signInResponse = try JSONDecoder().decode(SignInResponse.self, from: signInData)
        } catch {
            print("Error decoding completeSignIn data")
            completionHandler(); return
        }

        // --- Handle publicKeyCredentialRequestOptions (challenge + deviceAuthId) ---
        if let additional = signInResponse.additionalProperties,
           let optionsJSON = additional.publicKeyCredentialRequestOptions {
            if let data = optionsJSON.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let challengeInts = obj["challenge"] as? [Int] {
                PKDataManager.shared.challenge = parseChallenge(from: challengeInts)
            }
            if let deviceAuthId = additional.deviceAuthenticationId {
                PKDataManager.shared.deviceAuthenticationId = deviceAuthId
            }
            if let apUsername = additional.username, !apUsername.isEmpty {
                PKDataManager.shared.username = apUsername
            }
            if let userId = additional.userId {
                PKDataManager.shared.userId = userId
            }
            if let deviceId = additional.deviceId {
                PKDataManager.shared.deviceId = deviceId
            }
        }

        // Also read username from parameters.authorizationRequest.username
        if let paramsUsername = signInResponse.parameters?.authorizationRequest?.username,
           !paramsUsername.isEmpty {
            PKDataManager.shared.username = paramsUsername
        }

        // --- LAST-RESORT fallback: try raw JSON paths if decoding shapes differ ---
        if let raw = response,
           PKDataManager.shared.username?.isEmpty ?? true {
            if let parameters = raw["parameters"] as? [String: Any],
               let ar = parameters["authorizationRequest"] as? [String: Any],
               let u = ar["username"] as? String, !u.isEmpty {
                PKDataManager.shared.username = u
            } else if let additional = raw["additionalProperties"] as? [String: Any],
                      let u = additional["username"] as? String, !u.isEmpty {
                PKDataManager.shared.username = u
            }
        }

        // Debug
        print("👤 Username after signIn parse: \(PKDataManager.shared.username ?? "nil")")
        completionHandler()
    }
    
    // PKResponseHandler.swift
    func isSignUpRequired(_ response: [String: Any]?) -> Bool {
        // True registration indicator: creation options present
        if let additional = response?["additionalProperties"] as? [String: Any],
           additional["publicKeyCredentialCreationOptions"] != nil {
            return true
        }

        // Error-driven indicator (keep your existing logic)
        if let httpBody = response?["httpBody"] as? [String: Any],
           let error = httpBody["error"] as? [String: Any],
           let httpResponseCode = error["httpResponseCode"] as? Int,
           let details = error["details"] as? [[String: Any]],
           let raw = details.first?["rawResponse"] as? [String: Any],
           let code = raw["code"] as? String,
           httpResponseCode == 400, code == "NOT_FOUND" {
            return true
        }

        // Having requestOptions alone is the normal sign-in path → NOT sign-up
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
        
        // Handle both creation and request options for registration
        var optionsJson: String? = nil
        var isCreationFlow = false
        
        if let additionalProperties = signUpResponse.additionalProperties {
            if let creationOptions = additionalProperties.publicKeyCredentialCreationOptions {
                optionsJson = creationOptions
                isCreationFlow = true
                print("📋 Found publicKeyCredentialCreationOptions - proper registration flow")
            } else if let requestOptions = additionalProperties.publicKeyCredentialRequestOptions {
                optionsJson = requestOptions
                isCreationFlow = false
                print("📋 Found publicKeyCredentialRequestOptions - using for registration (DaVinci flow)")
            }
        }
        
        if let options = optionsJson {
            do {
                if let json = options.data(using: String.Encoding.utf8) {
                    if let jsonData = try JSONSerialization.jsonObject(with: json, options: .allowFragments) as? [String: AnyObject] {
                        if let challengeIntArray = jsonData["challenge"] as? [Int] {
                            PKDataManager.shared.challenge = parseChallenge(from: challengeIntArray)
                            print("✅ Challenge parsed: \(PKDataManager.shared.challenge?.base64EncodedString() ?? "nil")")
                        }
                        
                        if isCreationFlow {
                            // Standard WebAuthn creation flow
                            if let user = jsonData["user"] as? [String: Any], let idIntArray = user["id"] as? [Int] {
                                PKDataManager.shared.userIdData = parseChallenge(from: idIntArray)
                                print("✅ UserID parsed from user object: \(PKDataManager.shared.userIdData?.base64EncodedString() ?? "nil")")
                            }
                            if let user = jsonData["user"] as? [String: Any], let name = user["name"] as? String {
                                PKDataManager.shared.username = name
                                print("✅ Username from user object: \(name)")
                            }
                        } else {
                            // DaVinci flow - create synthetic user data for registration
                            if PKDataManager.shared.userIdData == nil {
                                // Generate a user ID based on the username
                                if let username = PKDataManager.shared.username {
                                    PKDataManager.shared.userIdData = username.data(using: .utf8)
                                    print("✅ Generated UserID from username: \(username)")
                                } else {
                                    // Fallback: generate random user ID
                                    let randomUserId = UUID().uuidString
                                    PKDataManager.shared.userIdData = randomUserId.data(using: .utf8)
                                    PKDataManager.shared.username = "user_\(randomUserId.prefix(8))"
                                    print("✅ Generated random UserID: \(randomUserId)")
                                }
                            }
                        }
                    }
                }
            } catch {
                print("❌ Error parsing options JSON: \(error.localizedDescription)")
                completionHandler()
                return
            }
            
            // Store additional properties
            if let additionalProperties = signUpResponse.additionalProperties {
                if let userId = additionalProperties.userId, let deviceId = additionalProperties.deviceId {
                    PKDataManager.shared.userId = userId
                    PKDataManager.shared.deviceId = deviceId
                    print("✅ Stored userId: \(userId), deviceId: \(deviceId)")
                }
            }
        }
        
        // Extract username from parameters if available
        if let parameters = signUpResponse.parameters, let authorizationRequest = parameters.authorizationRequest, let username = authorizationRequest.username {
            PKDataManager.shared.username = username
            print("✅ Username from parameters: \(username)")
        }
        
        completionHandler()
    }
    
    func parseChallenge(from challengeIntArray: [Int]) -> Data? {
        // Handle both positive and negative integers
        var arrUInt8 = [UInt8]()
        for num in challengeIntArray {
            if num >= 0 && num <= 255 {
                arrUInt8.append(UInt8(num))
            } else {
                // Handle negative values (two's complement)
                let unsigned = UInt8(bitPattern: Int8(num))
                arrUInt8.append(unsigned)
            }
        }
        return Data(arrUInt8)
    }
}
