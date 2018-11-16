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

    class func fetchReading(_ reading: BRReading, completion: @escaping (_ data: [String: Any], _ versesToUse: [Any], _ totalChunks: Int) -> Void) {
        // count total chunks
        var totalChunks = 0
        let books = BRReadingManager.books(for: reading)!
        let chapters = BRReadingManager.chapters(for: reading)!
        for b in 0..<books.count {
            if let bookChapters = chapters[b] as? [Any] {
                totalChunks += bookChapters.count
            }
        }

        let bookId = bookIdForBook(books[0] as! String)
        let chapterId = (chapters[0] as! [String])[0]
        let path = "v1/bibles/\(bibleId)/chapters/\(bookId).\(chapterId)?content-type=json&include-notes=false&include-chapter-numbers=false&include-verse-spans=false"
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
                    let verses = BRReadingManager.verses(for: reading)!
                    completion(dataObj, verses[0] as! [Any], totalChunks)
                }
                // fetch img src URL in metadata, which is for API usage/analytics (req'd by license)
                if let metaObj = dict["meta"] as? [String: Any],
                    let imgTag = metaObj["fumsNoScript"] as? String,
                    imgTag.contains("src=\"") {
                    let start = imgTag.index(imgTag.range(of: "src=\"")!.lowerBound, offsetBy: "src=\"".count)
                    let end = imgTag[start...].firstIndex(of: "\"")!
                    let metaUrl = URL(string: String(imgTag[start..<end]))!
                    print(metaUrl.absoluteString)

                    URLSession(configuration: URLSessionConfiguration.default)
                        .dataTask(with: metaUrl)
                        .resume()
                }
            }
        }
        task.resume()
    }

    class func fetchChunk(_ chunk: Int, forReading reading: BRReading, completion: @escaping (_ data: [String: Any], _ versesToUse: [Any]) -> Void) {
        print("fetch chunk", chunk)
    }
}

fileprivate func bookIdForBook(_ book: String) -> String {
    switch book {
    case "Gen.": return "GEN"
    case "Ps.": return "PSA"
    default: return ""
    }
}
