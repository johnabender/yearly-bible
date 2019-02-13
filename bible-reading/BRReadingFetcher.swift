//
//  BRReadingFetcher.swift
//  bible-reading
//
//  Created by John Bender on 11/14/18.
//  Copyright © 2018 Bender Systems. All rights reserved.
//

import UIKit

fileprivate let hashedApiKey = "2ae1" + "5c639c3d6217c0524ad5b7697286"
fileprivate let defaultBibleId = "06125adad2d5898a-01" // ASV

class BRReadingFetcher: NSObject {
    class func apiKey() -> String {
        return String(hashedApiKey[hashedApiKey.index(hashedApiKey.startIndex, offsetBy: 16)...] + hashedApiKey[..<hashedApiKey.index(hashedApiKey.startIndex, offsetBy: 16)])
    }

    class func baseUrl() -> URL? {
        return URL(string: "https://api.scripture.api.bible")
    }

    class func fetchReading(_ reading: BRReading, completion: @escaping (_ connectionError: Bool, _ apiError: Bool, _ data: [String: Any], _ verseIds: [String]?, _ totalChunks: Int) -> Void) {
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
        print(books, bookId, chapters, chapterId)

        // count total chunks
        var totalChunks = 0
        for c in chapters {
            totalChunks += c.count
        }
        print("total chunks:", totalChunks)

        self.fetchBookId(bookId, chapterId: chapterId) { (connectionError: Bool, apiError: Bool, data: [String: Any]?) in
            if connectionError || apiError {
                completion(connectionError, apiError, [:], nil, 0)
                return
            }
            guard let verses = BRReadingManager.verses(for: reading) as? [[Any]] else {
                print("didn't understand verses value for", reading)
                completion(false, false, data!, nil, totalChunks)
                return
            }
            if verses[0].count > 0,
                let bookVerses = verses[0] as? [String],
                bookVerses.count == 2,
                let firstVerse = Int(bookVerses[0]),
                let lastVerse = Int(bookVerses[1]) {
                var verseIds: [String] = []
                for v in firstVerse...lastVerse {
                    // if using JSON API:
                    //verseIds.append("\(bookId).\(chapterId).\(v)")
                    // else if using text API:
                    verseIds.append("\(v)")
                }
                print("fetcher sending verse IDs", verseIds)
                completion(false, false, data!, verseIds, totalChunks)
            }
            else {
                completion(false, false, data!, nil, totalChunks)
            }
        }
    }

    class func fetchChunk(_ chunk: Int, forReading reading: BRReading, completion: @escaping (_ data: [String: Any]) -> Void) {
        // assumption: fetchReading() has already been called with this reading,
        // so lots of validation can be skipped

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
            self.fetchBookId(bookId, chapterId: chapterToGet!) { (connectionError: Bool, apiError: Bool, data: [String : Any]?) in
                if data != nil {
                    completion(data!)
                }
            }
        }
        else {
            print("don't know the book ID for", bookToGet!)
        }
    }

    class func fetchBookId(_ bookId: String, chapterId: String, completion: @escaping (_ connectionError: Bool, _ apiError: Bool, _ data: [String: Any]?) -> Void) {
        var bibleId = defaultBibleId
        if let preferredTranslation = BRReadingManager.preferredTranslation() {
            bibleId = preferredTranslation.key
        }

        let path = "v1/bibles/\(bibleId)/chapters/\(bookId).\(chapterId)?content-type=text&include-notes=false&include-chapter-numbers=false"
        guard let biblesUrl = URL(string: path, relativeTo: self.baseUrl()) else { return }
        print(biblesUrl.absoluteString)

        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["api-key": self.apiKey()]
        let session = URLSession(configuration: config)
        let task = session.dataTask(with: biblesUrl) { (data: Data?, resp: URLResponse?, err: Error?) in
            if err != nil {
                print("connection error:", err!)
                completion(true, false, nil)
                return
            }
            else if let r = resp as? HTTPURLResponse,
                r.statusCode > 299 {
                print("API error:", r)
                completion(false, true, nil)
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data!, options: []),
                let dict = json as? [String: Any] {
                if let dataObj = dict["data"] as? [String: Any] {
                    completion(false, false, dataObj)
                }
                else {
                    completion(false, true, nil)
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
    case "Exod.": return "EXO"
    case "Lev.": return "LEV"
    case "Num.": return "NUM"
    case "Deut.": return "DEU"
    case "Josh.": return "JOS"
    case "Judg.": return "JDG"
    case "Ruth": return "RUT"
    case "1 Sam.": return "1SA"
    case "2 Sam.": return "2SA"
    case "1 Kin.": return "1KI"
    case "2 Kin.": return "2KI"
    case "1 Chr.": return "1CH"
    case "2 Chr.": return "2CH"
    case "Ezra": return "EZR"
    case "Neh.": return "NEH"
    case "Esth.": return "EST"
    case "Esther": return "EST"
    case "Job": return "JOB"
    case "Ps.": return "PSA"
    case "Prov.": return "PRO"
    case "Ecc.": return "ECC"
    case "Song": return "SNG"
    case "Isa.": return "ISA"
    case "Jer.": return "JER"
    case "Lamentations": return "LAM"
    case "Eze.": return "EZK"
    case "Dan.": return "DAN"
    case "Hos.": return "HOS"
    case "Joel": return "JOL"
    case "Amos": return "AMO"
    case "Obad.": return "OBA"
    case "Jon.": return "JON"
    case "Mic.": return "MIC"
    case "Micah": return "MIC"
    case "Nah.": return "NAM"
    case "Nahum": return "NAM"
    case "Hab.": return "HAB"
    case "Habakkuk": return "HAB"
    case "Zeph.": return "ZEP"
    case "Hagg.": return "HAG"
    case "Zech.": return "ZEC"
    case "Malachi": return "MAL"
    case "Mat.": return "MAT"
    case "Mark": return "MRK"
    case "Luke": return "LUK"
    case "John": return "JHN"
    case "Acts": return "ACT"
    case "Rom.": return "ROM"
    case "1 Cor.": return "1CO"
    case "2 Cor.": return "2CO"
    case "Gal.": return "GAL"
    case "Eph.": return "EPH"
    case "Phil.": return "PHP"
    case "Col.": return "COL"
    case "1 Th.": return "1TH"
    case "2 Thess.": return "2TH"
    case "1 Tim.": return "1TI"
    case "2 Tim.": return "2TI"
    case "2 Timothy": return "2TI"
    case "Titus": return "TIT"
    case "Philemon": return "PHM"
    case "Heb.": return "HEB"
    case "James": return "JAS"
    case "1 Pet.": return "1PE"
    case "2 Peter": return "2PE"
    case "1 Jn.": return "1JN"
    case "2 Jn.": return "2JN"
    case "3 Jn.": return "3JN"
    case "Jude": return "JUD"
    case "Rev.": return "REV"
    default: return nil
    }
}
