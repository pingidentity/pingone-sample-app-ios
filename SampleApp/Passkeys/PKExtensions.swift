//
//  PKExtensions.swift
//  SampleApp
//
//  Copyright © 2023 Ping Identity. All rights reserved.
//

import Foundation

extension String {
    func addQueryParams(name: String, value: String) -> String {
        // Convert to url
        guard let url = URL.init(string: self) else { return "" }
        guard let components = NSURLComponents(url: url, resolvingAgainstBaseURL: true) else { return "" }
        // Add query params
        var queryItems: [URLQueryItem] = components.queryItems ??  []
        let queryItem = URLQueryItem(name: name, value: value)
        queryItems.append(queryItem)
        components.queryItems = queryItems
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        // Update final url
        guard let urlStrFinal = components.url?.description else { return "" }
        return urlStrFinal
    }
}

extension Data {
    func base64URLEncode() -> String {
        let base64 = self.base64EncodedString()
        let base64URL = base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return base64URL
    }
}
