//
//  PKDataManager.swift
//  SampleApp
//
//  Copyright © 2023 Ping Identity. All rights reserved.
//

import Foundation

enum PingOneStatus: String, Codable {
    case signInRequired
    case signUpRequired
}

struct SignInResponse: Codable {
    let additionalProperties: AdditionalProperties?
}

struct SignUpResponse: Codable {
    let additionalProperties: AdditionalProperties?
    let parameters: Parameters?
}

struct AdditionalProperties: Codable {
    let publicKeyCredentialRequestOptions: String?
    let publicKeyCredentialCreationOptions: String?
    let challenge: [Int]?
    let deviceAuthenticationId: String?
    let username: String?
    let deviceId: String?
    let userId: String?
}

struct Parameters: Codable {
    let authorizationRequest: AuthorizationRequest?
}

struct AuthorizationRequest: Codable {
    let username: String?
}

class PKDataManager {
    static var shared = PKDataManager()
    var userIdData: Data?
    var userId: String?
    var username: String?
    var deviceAuthenticationId: String?
    var deviceId: String?
    var challenge: Data?
    var attestation: String?
    var assertion: String?
}
