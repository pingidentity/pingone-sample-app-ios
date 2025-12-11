//
//  Constants.swift
//  SampleApp
//
//  Created by Ping Identity on 10/10/19.
//  Copyright © 2019 Ping Identity. All rights reserved.
//

import Foundation

struct OIDC {
    static let Issuer                  = "<#Issuer#>"
    static let ClientID                = "<#clientId#>"
    static let RedirectURI             = "pingonesdk://sample"
}

struct OIDCKey {
    static let MobilePayload            = "mobilePayload"
    static let PromptKey                = "prompt"
    static let PromptValue              = "login"
}

struct PairingMethodName {
    static let Manual                   = "Manual Pairing"
    static let OIDC                     = "OIDC Automatic Pairing"
}

struct AuthnAPIName {
    static let authnAPI                 = "Authentication API"
}

struct SDKFunctionality {
    static let OneTimePasscode          = "One Time Passcode"
    static let QRAuth                   = "QR Authentication"
    static let SendLogs                 = "SendLogs"
    static let Passkeys                 = "Passkeys"
    static let NotificationTest         = "Notifications Test"
}

struct SegueName {
    static let Manual                   = "manual"
    static let OIDC                     = "oidc"
    static let authnAPI                 = "authnapi"
    static let passcode                 = "passcode"
    static let QRAuth                   = "QRAuth"
    static let UserApproval             = "UserApproval"
    static let Passkeys                 = "passkeys"
    static let NotificationTest         = "testpush"
}

struct Local {
    static let DeviceIsPaired                   = "Device is paired successfully."
    static let Pair                             = "Pair?"
    static let Authenticate                     = "Authenticate?"
    static let Approve                          = "Approve"
    static let Deny                             = "Deny"
    static let Cancel                           = "Cancel"
    static let Success                          = "SUCCESS"
    static let Error                            = "ERROR"
    static let Ok                               = "OK"
    static let appTitle                         = "PingOne Sample Application"
    static let AuthCompleted                    = "Authentication completed successfully"
    static let AuthStatusExpired                = "EXPIRED"
    static let AuthStatusClaimed                = "CLAIMED"
    static let AuthStatusCompleted              = "COMPLETED"
    static let AuthUserApprovalNOTRequired      = "NOT_REQUIRED"
    static let AuthUserApprovalRequired         = "REQUIRED"
    static let UserSelectionTitle               = "Do you want to approve authentication for a user"
    static let ClientContextPlaceholder         = "clientContext will be placed here if returned from the SDK"
    static let NumMatchingPick                  = "Set a number for authentication"
}

struct Push {
    static let aps                     = "aps"
    static let alert                   = "alert"
    static let title                   = "title-loc-key"
    static let body                    = "loc-key"
    static let NumberMatchingOptions   = "SELECT_NUMBER"
    static let NumberMatchingManual    = "ENTER_MANUALLY"
}

struct PushTestIdentifiers {
    static let APNSSandbox              = "Sandbox"
    static let APNSProduction           = "Production"
}

struct OneTimePasscodeError {
    static let notPaired               = "Device Not Paired"
}

struct Passkeys {
    static let EnvId                   = "<#passkeysEnvId#>"
    static let ClientId                = "<#passkeysClientId#>"
    static let UrlBase                 = "<#passkeysUrlBase#>"
    static let AuthUrl                 = "\(UrlBase)/\(EnvId)/as/authorize?client_id=\(ClientId)&scope=openid&response_type=code&response_mode=pi.flow"
    static let Domain                  = "<#passkeysRpId#>"
    static let RpId                    = "https://\(Domain)"
    static let RpIdKey                 = "rpId"
    static let LoginToCreatePasskey    = "Login to create a Passkey."
    static let Login                   = "Login to create account"
    static let Username                = "username"
    static let Password                = "password"
    static let Submit                  = "Submit"
    static let RegisterComplete        = "Passkey register completed."
    static let ErrorDomainPingOne      = "PingOneErrorDomain"
    static let DeviceAuthenticationId  = "deviceAuthenticationId"
    static let Assertion               = "assertion"
    static let Attestation             = "attestation"
    static let UserId                  = "userId"
    static let DeviceId                = "deviceId"
    static let Origin                  = "origin"
    static let missingCredMsg          = "Please remove placeholders from Constants file and add your own credentials."
    static let isAutoEnrollmentEnabled =  true
    // ADDED: Debug method to verify endpoint is working
    static func validateEndpoint(completion: @escaping (Bool) -> Void) {
        print("🔍 Validating PingOne endpoint configuration...")

        guard let url = URL(string: AuthUrl) else {
            print("❌ Invalid URL format")
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                completion(false)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                completion(false)
                return
            }

            print("📊 HTTP Status: \(httpResponse.statusCode)")
            print("📊 Content-Type: \(httpResponse.allHeaderFields["Content-Type"] ?? "unknown")")

            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                let isJSON = responseString.starts(with: "{") || responseString.starts(with: "[")
                let isHTML = responseString.starts(with: "<")

                print("📊 Response type: \(isJSON ? "JSON ✅" : isHTML ? "HTML ❌" : "Unknown")")
                print("📊 Response length: \(responseString.count) characters")

                if isJSON {
                    print("✅ Endpoint returning JSON - configuration correct")
                    completion(true)
                } else {
                    print("❌ Endpoint returning HTML - wrong environment/configuration")
                    print("First 200 chars: \(String(responseString.prefix(200)))")
                    completion(false)
                }
            } else {
                print("❌ No response data")
                completion(false)
            }
        }.resume()
    }

}
