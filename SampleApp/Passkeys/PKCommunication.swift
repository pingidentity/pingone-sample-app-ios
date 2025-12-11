//
//  PKCommunication.swift
//  SampleApp
//
//  Copyright © 2023 Ping Identity. All rights reserved.
//

import Foundation

final class PKCommunication {
    func sendHttpRequest(urlStr: String, jsonData: [String: Any]? = nil,
              completionHandler: @escaping (_ response: [String: Any]?, _ error: NSError?) -> Void) {
        guard let requestUrl = URL(string: urlStr) else { return }

#if DEBUG
        print("**************************************************")
        print("Sending URL:     \(urlStr)")
        print("Sending data:     \(String(describing: jsonData))")
        print("**************************************************")
#endif

        var urlRequest = URLRequest(url: requestUrl)
        urlRequest.httpMethod = jsonData == nil ? "GET" : "POST"

        // Always prefer JSON responses
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        if let jsonData = jsonData {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            do {
                urlRequest.httpBody = try JSONSerialization.data(withJSONObject: jsonData)
                print("📋 Sending JSON payload in body")
            } catch {
                completionHandler(nil, NSError(domain: "PKCommunication",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "JSON serialization failed"]))
                return
            }
        } else {
            urlRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        }

        let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            guard let data = data, error == nil else { completionHandler(nil, error as NSError?); return }

            guard let responseString = String(data: data, encoding: .utf8) else {
                print("Response unprintable")
                completionHandler(nil, NSError(domain: "PKCommunication",
                                               code: -1,
                                               userInfo: [NSLocalizedDescriptionKey: "Failed to parse response as UTF-8 string"]))
                return
            }

#if DEBUG
        print("**************************************************")
        print("Response:   \(String(describing: responseString))")
        print("**************************************************")
#endif

            // Quick sniff: did we accidentally hit HTML?
            guard (responseString.trimmingCharactersAsWhitespace().hasPrefix("<!doctype html") || responseString.contains("<html")) == false else {
                print("❌ HTML response detected — likely wrong endpoint or missing query params.")
                completionHandler(nil, NSError(domain: "PKCommunication",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Server returned HTML page instead of JSON"]))
                return
            }

            // Parse JSON
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    completionHandler(json, nil)
                } else {
                    completionHandler(nil, NSError(domain: "PKCommunication",
                        code: -3,
                        userInfo: [NSLocalizedDescriptionKey: "Unexpected response type"]))
                }
            } catch {
                print("error parsing httpResponse to json")
                completionHandler(nil, NSError(domain: "PKCommunication",
                    code: -4,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"]))
            }
            print("Communication task finished successfully")
        }
        task.resume()
    }
}

private extension String {
    func trimmingCharactersAsWhitespace() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

