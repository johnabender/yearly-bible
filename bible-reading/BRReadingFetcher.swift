//
//  BRReadingFetcher.swift
//  bible-reading
//
//  Created by John Bender on 11/14/18.
//  Copyright © 2018 Bender Systems. All rights reserved.
//

import UIKit

fileprivate let hashedApiKey = "2ae1" + "5c639c3d6217c0524ad5b7697286"
fileprivate let baseUrl = URL(string: "https://api.scripture.api.bible")
fileprivate let bibleId = "06125adad2d5898a-01" // ASV

class BRReadingFetcher: NSObject {
    class func apiKey() -> String {
        return String(hashedApiKey[hashedApiKey.index(hashedApiKey.startIndex, offsetBy: 16)...] + hashedApiKey[..<hashedApiKey.index(hashedApiKey.startIndex, offsetBy: 16)])
    }

    class func fetchReading(_ reading: BRReading, completion: @escaping ([String: Any]) -> Void) {
        let path = "v1/bibles/" + bibleId + "/chapters/GEN.1?content-type=json&include-notes=false&include-chapter-numbers=false&include-verse-spans=false"
        guard let biblesUrl = URL(string: path, relativeTo: baseUrl) else { return }
        print(biblesUrl.absoluteString)
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["api-key": self.apiKey()]
        let session = URLSession(configuration: config)
        let task = session.dataTask(with: biblesUrl) { (data: Data?, resp: URLResponse?, err: Error?) in
            if err != nil {
                print("API error:", err!)
                return
            }
            if let json = try? JSONSerialization.jsonObject(with: data!, options: []),
                let dict = json as? [String: Any] {
                if let dataObj = dict["data"] as? [String: Any] {
                    completion(dataObj)
                }
                if let metaObj = dict["meta"] as? [String: Any] {
                    // TODO: load meta 
                }
            }
        }
        task.resume()
    }
}
