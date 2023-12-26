//
//  PKCommunication.swift
//  SampleApp
//
//  Copyright © 2023 Ping Identity. All rights reserved.
//

import Foundation

final class PKCommunication {
    
    func post(urlStr: String, completionHandler: @escaping (_ response: [String: Any]?, _ error: NSError?) -> Void) {

        guard let requestUrl =  URL(string: urlStr) else {
            return
        }
        
        var urlRequest = URLRequest(url: requestUrl)
        urlRequest.httpMethod = "GET"
        
        urlRequest.allHTTPHeaderFields = ["ContentType": "application/json"]
        
        #if DEBUG
        print("**************************************************")
        print("Sending Url:     \(requestUrl)")
        print("**************************************************")
        #endif
        
        // Send request
        let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
                        
            guard let data = data, error == nil else {
                completionHandler(nil, error as NSError?)
                return
            }
                
            let httpResponse = response as! HTTPURLResponse

            if let responseString = String(data: data, encoding: .utf8) {
                print("Response:     \(String(describing: responseString))")
                
                // Cookie handle
                if let url = httpResponse.url,
                    let allHeaderFields = httpResponse.allHeaderFields as? [String: String] {
                    let cookies = HTTPCookie.cookies(withResponseHeaderFields: allHeaderFields, for: url)
                    HTTPCookieStorage.shared.setCookies(cookies, for: url, mainDocumentURL: nil)
                }
                
                // Get the json response
                var jsonDictionary: NSDictionary?
                
                do {
                    jsonDictionary = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers) as? NSDictionary
                } catch {
                    print("error parsing httpResponse to json")
                }

                if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                    if jsonDictionary != nil {
                        completionHandler(jsonDictionary as? [String: Any], nil)
                    }
                } else {
                    let error = NSError.init(domain: Passkeys.ErrorDomainPingOne, code: httpResponse.statusCode, userInfo: jsonDictionary as? [String: Any] ?? [:])
                    print("Received error response: \(error.localizedDescription)")
                        completionHandler(nil, error as NSError?)
                }
                
            }
            print("Communication task finished successfully")
        }
        task.resume()
    }
}
