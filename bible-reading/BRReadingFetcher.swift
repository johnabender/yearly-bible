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
    
    class func fetchReading(_ reading: Reading, completion: @escaping (_ connectionError: Bool, _ apiError: Bool, _ data: [String: Any], _ verseIds: [String]?, _ totalChunks: Int) -> Void) {
        let totalChunks = reading.passages.reduce(0) { $0 + $1.chapters.count }

        let passage = reading.passages.first!
        let bookId = bookIdForBook(passage.book)
        print("fetcher bookId: \(bookId) chapterId: \(passage.chapters.first!)")
        self.fetchBookId(bookId, chapterId: passage.chapters.first!) { (connectionError: Bool, apiError: Bool, data: [String: Any]?) in
            if connectionError || apiError {
                completion(connectionError, apiError, [:], nil, 0)
                return
            }
            if let verses = passage.verses {
                if let firstVerse = verses.first,
                   let lastVerse = verses.last {
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
            else {
                completion(false, false, data!, nil, totalChunks)
            }
        }
    }
    
    class func fetchChunk(_ chunk: Int, forReading reading: Reading, completion: @escaping (_ data: [String: Any]) -> Void) {
        // don't bother with verses, assuming that if a reading has more
        // than one chunk, then all the chunks are complete chapters
        var chunkCount = 0
        var passageToGet: Passage = reading.passages.first!
        var chapterToGet: Int = 1

        for p in reading.passages {
            if chunkCount + p.chapters.count < chunk {
                chunkCount += p.chapters.count
                continue
            }
            passageToGet = p
            chapterToGet = p.chapters[chunk - chunkCount - 1]
            break
        }
        
        let bookId = bookIdForBook(passageToGet.book)
        print("fetcher chunk: \(chunk) bookId: \(bookId) chapterId: \(chapterToGet)")
        self.fetchBookId(bookId, chapterId: chapterToGet) { (connectionError: Bool, apiError: Bool, data: [String : Any]?) in
            if data != nil {
                completion(data!)
            }
        }
    }
    
    class func fetchBookId(_ bookId: String, chapterId: Int, completion: @escaping (_ connectionError: Bool, _ apiError: Bool, _ data: [String: Any]?) -> Void) {
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
    
    fileprivate class func bookIdForBook(_ book: Book) -> String {
        switch book.bookIndex {
        case .Genesis: return "GEN"
        case .Exodus: return "EXO"
        case .Leviticus: return "LEV"
        case .Numbers: return "NUM"
        case .Deuteronomy: return "DEU"
        case .Joshua: return "JOS"
        case .Judges: return "JDG"
        case .Ruth: return "RUT"
        case .Samuel1: return "1SA"
        case .Samuel2: return "2SA"
        case .Kings1: return "1KI"
        case .Kings2: return "2KI"
        case .Chronicles1: return "1CH"
        case .Chronicles2: return "2CH"
        case .Ezra: return "EZR"
        case .Nehemiah: return "NEH"
        case .Esther: return "EST"
        case .Job: return "JOB"
        case .Psalms: return "PSA"
        case .Proverbs: return "PRO"
        case .Ecclesiastes: return "ECC"
        case .SongOfSolomon: return "SNG"
        case .Isaiah: return "ISA"
        case .Jeremiah: return "JER"
        case .Lamentations: return "LAM"
        case .Ezekiel: return "EZK"
        case .Daniel: return "DAN"
        case .Hosea: return "HOS"
        case .Joel: return "JOL"
        case .Amos: return "AMO"
        case .Obadiah: return "OBA"
        case .Jonah: return "JON"
        case .Micah: return "MIC"
        case .Nahum: return "NAM"
        case .Habakkuk: return "HAB"
        case .Zephaniah: return "ZEP"
        case .Haggai: return "HAG"
        case .Zechariah: return "ZEC"
        case .Malachi: return "MAL"
        case .Matthew: return "MAT"
        case .Mark: return "MRK"
        case .Luke: return "LUK"
        case .John: return "JHN"
        case .Acts: return "ACT"
        case .Romans: return "ROM"
        case .Corinthians1: return "1CO"
        case .Corinthians2: return "2CO"
        case .Galatians: return "GAL"
        case .Ephesians: return "EPH"
        case .Philippians: return "PHP"
        case .Colossians: return "COL"
        case .Thessalonians1: return "1TH"
        case .Thessalonians2: return "2TH"
        case .Timothy1: return "1TI"
        case .Timothy2: return "2TI"
        case .Titus: return "TIT"
        case .Philemon: return "PHM"
        case .Hebrews: return "HEB"
        case .James: return "JAS"
        case .Peter1: return "1PE"
        case .Peter2: return "2PE"
        case .John1: return "1JN"
        case .John2: return "2JN"
        case .John3: return "3JN"
        case .Jude: return "JUD"
        case .Revelation: return "REV"
        }
    }
}
