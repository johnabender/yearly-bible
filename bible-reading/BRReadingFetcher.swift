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

    class func fetchReading(_ reading: BRReading, completion: @escaping (_ data: [String: Any], _ verseIds: [String]?, _ totalChunks: Int) -> Void) {
        guard let books = BRReadingManager.books(for: reading) as? [String] else {
            print("didn't understand books value for", reading)
            return
        }
        guard let chapters = BRReadingManager.chapters(for: reading) as? [[String]] else {
            print("didn't understand chapters value for", reading)
            return
        }
        if books.count < 1 {
            print("returned no books for", reading)
            return
        }
        if books.count != chapters.count {
            print("mismatched counts in", books, chapters)
            return
        }
        guard let bookId = bookIdForBook(books[0]) else {
            print("don't have a valid book ID for", books[0])
            return
        }
        if chapters[0].count < 1 {
            print("returned no chapters for", reading)
            return
        }
        let chapterId = chapters[0][0]

        // count total chunks
        var totalChunks = 0
        for c in chapters {
            totalChunks += c.count
        }
        print("total chunks:", totalChunks)

        self.fetchBookId(bookId, chapterId: chapterId) { (data: [String: Any]) in
            guard let verses = BRReadingManager.verses(for: reading) as? [[Any]] else {
                print("didn't understand verses value for", reading)
                completion(data, nil, totalChunks)
                return
            }
            if verses[0].count > 0,
                let bookVerses = verses[0] as? [[String]],
                bookVerses.count > 0,
                bookVerses[0].count == 2,
                let firstVerse = Int(bookVerses[0][0]),
                let lastVerse = Int(bookVerses[0][1]) {
                var verseIds: [String] = []
                for v in firstVerse...lastVerse {
                    verseIds.append("\(bookId).\(chapterId).\(v)")
                }
                completion(data, verseIds, totalChunks)
            }
            else {
                print(verses, verses[0].count)
                if let cv = verses[0] as? [String] {
                    print(cv, cv.count)
                }
                else {
                    print("verses not a string-string array")
                }
                completion(data, nil, totalChunks)
            }
        }
    }

    class func fetchChunk(_ chunk: Int, forReading reading: BRReading, completion: @escaping (_ data: [String: Any]) -> Void) {
        // assumption: fetchReading() has already been called with this reading,
        // so lots of upfront validation can be skipped

        // don't bother with verses, assuming that if a reading has more
        // than one chunk, then all the chunks are complete chapters
        print("fetch chunk", chunk)
        let books = BRReadingManager.books(for: reading)!
        let chapters = BRReadingManager.chapters(for: reading)!

        var chunkCount = 0
        var bookToGet: String?
        var chapterToGet: String?

        for b in 0..<books.count {
            if let bookChapters = chapters[b] as? [Any] {
                for c in 0..<bookChapters.count {
                    chunkCount += 1
                    if chunkCount == chunk {
                        chapterToGet = bookChapters[c] as? String
                        break
                    }
                }
            }
            if chunkCount == chunk {
                bookToGet = books[b] as? String
                break
            }
        }

        if let bookId = bookIdForBook(bookToGet!) {
            self.fetchBookId(bookId, chapterId: chapterToGet!) { (_ data: [String : Any]) in
                completion(data)
            }
        }
        else {
            print("don't know the book ID for", bookToGet!)
        }
    }

    class func fetchBookId(_ bookId: String, chapterId: String, completion: @escaping (_ data: [String: Any]) -> Void) {
        let path = "v1/bibles/\(bibleId)/chapters/\(bookId).\(chapterId)?content-type=json&include-notes=false&include-chapter-numbers=false&include-verse-spans=false"
        guard let biblesUrl = URL(string: path, relativeTo: baseUrl) else { return }
        print(biblesUrl.absoluteString)

        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["api-key": self.apiKey()]
        let session = URLSession(configuration: config)
        let task = session.dataTask(with: biblesUrl) { (data: Data?, resp: URLResponse?, err: Error?) in
            if err != nil {
                print("connection error:", err!)
                return
            }
            else if let r = resp as? HTTPURLResponse,
                r.statusCode > 299 {
                print("API error:", r)
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data!, options: []),
                let dict = json as? [String: Any] {
                if let dataObj = dict["data"] as? [String: Any] {
                    completion(dataObj)
                }

                // fetch img src URL in metadata, which is for API usage/analytics (req'd by license)
                if let metaObj = dict["meta"] as? [String: Any],
                    let imgTag = metaObj["fumsNoScript"] as? String,
                    imgTag.contains("src=\"") {
                    let start = imgTag.index(imgTag.range(of: "src=\"")!.lowerBound, offsetBy: "src=\"".count)
                    let end = imgTag[start...].firstIndex(of: "\"")!
                    // change from https to http, because SSL lib logs garbage otherwise
                    var imgPath = String(imgTag[start..<end])
                    if imgPath.hasPrefix("https") {
                        imgPath = "http" + imgPath[imgPath.index(imgPath.startIndex, offsetBy: "https".count)...]
                    }

                    let metaUrl = URL(string: imgPath)!
                    print(metaUrl.absoluteString)
                    URLSession(configuration: URLSessionConfiguration.default)
                        .dataTask(with: metaUrl)
                        .resume()
                }
            }
        }
        task.resume()
    }
}

fileprivate func bookIdForBook(_ book: String) -> String? {
    switch book {
    case "Gen.": return "GEN"
    case "Malachi": return "MAL"
    case "Ps.": return "PSA"
    case "Jude": return "JUD"
    default: return nil
    }
}
