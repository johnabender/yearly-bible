//
//  Passage.swift
//  bible-reading
//
//  Created by John Bender on 1/23/25.
//  Copyright © 2025 Bender Systems. All rights reserved.
//

import Foundation
import Algorithms

@objc enum BookIndex: Int {
    case Genesis
    case Exodus
    case Leviticus
    case Numbers
    case Deuteronomy
    case Joshua
    case Judges
    case Ruth
    case Samuel1
    case Samuel2
    case Kings1
    case Kings2
    case Chronicles1
    case Chronicles2
    case Ezra
    case Nehemiah
    case Esther
    case Job
    case Psalms
    case Proverbs
    case Ecclesiastes
    case SongOfSolomon
    case Isaiah
    case Jeremiah
    case Lamentations
    case Ezekiel
    case Daniel
    case Hosea
    case Joel
    case Amos
    case Obadiah
    case Jonah
    case Micah
    case Nahum
    case Habakkuk
    case Zephaniah
    case Haggai
    case Zechariah
    case Malachi
    case Matthew
    case Mark
    case Luke
    case John
    case Acts
    case Romans
    case Corinthians1
    case Corinthians2
    case Galatians
    case Ephesians
    case Philippians
    case Colossians
    case Thessalonians1
    case Thessalonians2
    case Timothy1
    case Timothy2
    case Titus
    case Philemon
    case Hebrews
    case James
    case Peter1
    case Peter2
    case John1
    case John2
    case John3
    case Jude
    case Revelation
}

class Book: NSObject {
    var bookIndex: BookIndex
    
    override var description: String {
        switch bookIndex {
        case .Genesis: return "Gen."
        case .Exodus: return "Exod."
        case .Leviticus: return "Lev."
        case .Numbers: return "Num."
        case .Deuteronomy: return "Deut."
        case .Joshua: return "Josh."
        case .Judges: return "Judg."
        case .Ruth: return "Ruth"
        case .Samuel1: return "1 Sam."
        case .Samuel2: return "2 Sam."
        case .Kings1: return "1 Kin."
        case .Kings2: return "2 Kin."
        case .Chronicles1: return "1 Chr."
        case .Chronicles2: return "2 Chr."
        case .Ezra: return "Ezra"
        case .Nehemiah: return "Neh."
        case .Esther: return "Esth."
        case .Job: return "Job"
        case .Psalms: return "Ps."
        case .Proverbs: return "Prov."
        case .Ecclesiastes: return "Ecc."
        case .SongOfSolomon: return "Song"
        case .Isaiah: return "Isa."
        case .Jeremiah: return "Jer."
        case .Lamentations: return "Lament."
        case .Ezekiel: return "Eze."
        case .Daniel: return "Dan."
        case .Hosea: return "Hos."
        case .Joel: return "Joel"
        case .Amos: return "Amos"
        case .Obadiah: return "Obad."
        case .Jonah: return "Jon."
        case .Micah: return "Mic."
        case .Nahum: return "Nah."
        case .Habakkuk: return "Hab."
        case .Zephaniah: return "Zeph."
        case .Haggai: return "Hagg."
        case .Zechariah: return "Zech."
        case .Malachi: return "Mal."
        case .Matthew: return "Matt."
        case .Mark: return "Mark"
        case .Luke: return "Luke"
        case .John: return "John"
        case .Acts: return "Acts"
        case .Romans: return "Rom."
        case .Corinthians1: return "1 Cor."
        case .Corinthians2: return "2 Cor."
        case .Galatians: return "Gal."
        case .Ephesians: return "Eph."
        case .Philippians: return "Phil."
        case .Colossians: return "Col."
        case .Thessalonians1: return "1 Th."
        case .Thessalonians2: return "2 Th."
        case .Timothy1: return "1 Tim."
        case .Timothy2: return "2 Tim."
        case .Titus: return "Titus"
        case .Philemon: return "Philemon"
        case .Hebrews: return "Heb."
        case .James: return "James"
        case .Peter1: return "1 Pet."
        case .Peter2: return "2 Pet."
        case .John1: return "1 Jn."
        case .John2: return "2 Jn."
        case .John3: return "3 Jn."
        case .Jude: return "Jude"
        case .Revelation: return "Rev."
        }
    }
        
    var nChapters: Int {
        switch bookIndex {
        case .Genesis: return 50
        case .Exodus: return 40
        case .Leviticus: return 27
        case .Numbers: return 36
        case .Deuteronomy: return 34
        case .Joshua: return 24
        case .Judges: return 21
        case .Ruth: return 4
        case .Samuel1: return 31
        case .Samuel2: return 24
        case .Kings1: return 22
        case .Kings2: return 25
        case .Chronicles1: return 29
        case .Chronicles2: return 36
        case .Ezra: return 10
        case .Nehemiah: return 13
        case .Esther: return 10
        case .Job: return 42
        case .Psalms: return 150
        case .Proverbs: return 31
        case .Ecclesiastes: return 12
        case .SongOfSolomon: return 8
        case .Isaiah: return 66
        case .Jeremiah: return 52
        case .Lamentations: return 5
        case .Ezekiel: return 48
        case .Daniel: return 12
        case .Hosea: return 14
        case .Joel: return 3
        case .Amos: return 9
        case .Obadiah: return 1
        case .Jonah: return 4
        case .Micah: return 7
        case .Nahum: return 3
        case .Habakkuk: return 3
        case .Zephaniah: return 3
        case .Haggai: return 2
        case .Zechariah: return 14
        case .Malachi: return 4
        case .Matthew: return 28
        case .Mark: return 16
        case .Luke: return 24
        case .John: return 21
        case .Acts: return 28
        case .Romans: return 16
        case .Corinthians1: return 16
        case .Corinthians2: return 13
        case .Galatians: return 6
        case .Ephesians: return 6
        case .Philippians: return 4
        case .Colossians: return 4
        case .Thessalonians1: return 5
        case .Thessalonians2: return 3
        case .Timothy1: return 6
        case .Timothy2: return 4
        case .Titus: return 3
        case .Philemon: return 1
        case .Hebrews: return 13
        case .James: return 5
        case .Peter1: return 5
        case .Peter2: return 3
        case .John1: return 5
        case .John2: return 1
        case .John3: return 1
        case .Jude: return 1
        case .Revelation: return 22
        }
    }
    
    @objc init(index: BookIndex) {
        bookIndex = index
    }
}

class Passage: NSObject {
    var book: Book
    var chapters: [Int]
    var verses: [Int]?

    override var description: String {
        return "\(book) \(chapters) : \(verses ?? [])"
    }
    
    @objc init(withBook: Book) {
        book = withBook
        chapters = Array(1...book.nChapters)
    }
    @objc init(withBook: Book, multipleChapters: [Int]) {
        book = withBook
        chapters = multipleChapters
    }
    @objc init(withBook: Book, oneChapter: Int) {
        book = withBook
        chapters = [oneChapter]
    }
    @objc init(withBook: Book, startingChapter: Int, endingChapter: Int) {
        book = withBook
        chapters = Array(startingChapter...endingChapter)
    }
    @objc init(withBook: Book, oneChapter: Int, startingVerse: Int, endingVerse: Int) {
        book = withBook
        chapters = [oneChapter]
        verses = [startingVerse, endingVerse]
    }
    
    @objc init(dictionary dict: NSDictionary) {
        book = Book(index: BookIndex(rawValue: (dict["book"] as! NSNumber).intValue)!)
        chapters = dict["chapters"] as! [Int]
        if let versesArray = dict["verses"] as? [Int] {
            verses = versesArray
        } else {
            verses = nil
        }
    }
    
    func dictionaryRepresentation() -> NSDictionary {
        let dict: NSMutableDictionary = [:]
        dict["book"] = NSNumber(value: book.bookIndex.rawValue)
        dict["chapters"] = chapters
        if let verses = verses {
            dict["verses"] = verses
        }
        return NSDictionary(dictionary: dict)
    }
    
    func isEqual(_ other: Passage) -> Bool {
        return self.description == other.description
    }
    
    func displayText() -> String {
        var str = "\(book.description) "
        if chapters.count != book.nChapters {
            /*
             Append chapter numbers to str.
             While chapter numbers are sequential, use a '-' for the range.
             If chapter numbers are non-sequential, use a ',' between two groups.
             Example inputs:
               [2]
               [3, 4, 5]
               [6, 8]
               [1, 2, 3, 14, 16, 17, 18; 22, 23, 25]
             Example outputs:
               "2"
               "3-5"
               "6, 8"
               "1-3, 14, 16-17, 22-23, 25"
             */
            let chunks = chapters.chunked(by: { $1 == $0 + 1 }) // from github.com/apple/swift-algorithms
            for chunk in chunks {
                if chunk.count == 1 {
                    str += "\(chunk.first!)"
                }
                else {
                    str += "\(chunk.first!)-\(chunk.last!)"
                }
                if chunk != chunks.last {
                    str += ", "
                }
            }
        }
        if let verses = verses {
            str += ":\(verses.first!)"
            if verses.count > 1 {
                str += "-\(verses.last!)"
            }
        }
        return str
    }
}

class Reading: NSObject {
    @objc var day: String
    var passages: [Passage]
    @objc var read: Bool
    
    override var description: String {
        return "\(day): \(passages) [\(read ? "x" : " ")]"
    }

    @objc init(withDay: String, passages thePassages: [Passage]) {
        day = withDay
        passages = thePassages
        read = false
    }
    
    @objc init(dictionary dict: NSDictionary) {
        day = dict["day"] as! String
        if let passageArray = dict["passageArray"] as? [[String: Any]] {
            passages = passageArray.map({ Passage(dictionary: NSDictionary(dictionary: $0)) })
        } else {
//            let reading = BRReading.init(dictionary: (dict as! [AnyHashable : Any]))
            passages = []
        }
        read = false
        if let read = dict["read"] as? NSNumber {
            if read.boolValue {
                self.read = true
            }
        }
    }
    
    @objc func dictionaryRepresentation() -> NSDictionary {
        let dict: NSMutableDictionary = [:]
        dict["day"] = day
        dict["passageArray"] = passages.map({ $0.dictionaryRepresentation() })
        if (read) {
            dict["read"] = NSNumber(booleanLiteral: true)
        }
        return NSDictionary(dictionary: dict)
    }
    
    @objc override func isEqual(_ object: Any?) -> Bool {
        if let other = object as? Reading {
            return (day == other.day)
            && passages.count == other.passages.count
            && (0..<passages.count).map({ passages[$0].isEqual(other.passages[$0]) })
                .reduce(false, { $0 && $1 })
            //        return self.description() == other.description()
        }
        return false
    }
    
    @objc func displayText() -> String {
        var str = ""
        for passage in passages {
            str += "\(passage.displayText()), "
        }
        str.removeLast(2)
        return str
    }
}
