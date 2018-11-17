//
//  BRReadingViewController.swift
//  bible-reading
//
//  Created by John Bender on 11/13/18.
//  Copyright © 2018 Bender Systems. All rights reserved.
//

import UIKit

fileprivate let chapterFont = UIFont(name: "KingThingsFoundation", size: 17)!
fileprivate let chapterAttributes = [NSAttributedString.Key.font: chapterFont]
fileprivate let textFont = UIFont(name: "Gentium Basic", size: 15)!
fileprivate let textAttributes = [NSAttributedString.Key.font: textFont]
fileprivate let verseFont = UIFont(name: "KingThingsFoundation", size: 10)!
fileprivate let verseAttributes = [NSAttributedString.Key.font: verseFont,
                                   NSAttributedString.Key.baselineOffset: NSNumber(value: 5),
                                   NSAttributedString.Key.obliqueness: NSNumber(value: 0.1)]

class BRReadingViewController: UIViewController, UIScrollViewDelegate {

    @IBOutlet weak var contentView: UIView?
    @IBOutlet weak var markButton: UIButton?
    @IBOutlet weak var textView: UITextView?

    @IBOutlet weak var spinner: UIActivityIndicatorView?
    @IBOutlet weak var spinnerCenterYConstraint: NSLayoutConstraint?

    @objc var reading: BRReading?
    @objc var markReadAction: ((BRReading?) -> Void)?

    fileprivate var loadedChunks = 0
    fileprivate var totalChunks = 0
    fileprivate var isLoadingChunk = true

    override func viewDidLoad() {
        super.viewDidLoad()

        self.markButton?.setTitle(BRMarkReadString, for: .normal)

        if self.reading != nil {
            BRReadingFetcher.fetchReading(self.reading!) { (data: [String: Any], verseIds: [String]?, totalChunks: Int) in
                self.totalChunks = totalChunks
                self.loadedChunks = 1
                self.isLoadingChunk = false

                // TODO: use only specified verses
                let readingText = attributedStringFromData(data, verseIds: verseIds)
                OperationQueue.main.addOperation {
                    self.spinner?.stopAnimating()
                    self.spinnerCenterYConstraint?.constant = (self.textView?.frame.size.height ?? 0)/2 - (self.spinner?.frame.size.height ?? 0)
                    self.textView?.attributedText = readingText
                    self.textView?.isScrollEnabled = true

                    if let cs = self.textView?.contentSize.height,
                        let fs = self.textView?.frame.size.height,
                        cs < fs,
                        self.totalChunks > 1 {
                        self.loadNextChunk()
                    }
                }
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if false && self.contentView != nil && self.textView != nil {
            let gradientLayer = CAGradientLayer()
            gradientLayer.frame = self.contentView!.bounds
            gradientLayer.colors = [UIColor.white.cgColor, UIColor.clear.cgColor, UIColor.white.cgColor]
            let bottomOffset = (self.textView!.frame.size.height + self.textView!.frame.origin.y + 1)/self.contentView!.bounds.size.height
            let topOffset = bottomOffset - 0.1
            let bottomCoordinate = NSNumber(value: Double(bottomOffset))
            let topCoordinate = NSNumber(value: Double(topOffset))
            gradientLayer.locations = [topCoordinate, bottomCoordinate, bottomCoordinate]
            self.contentView!.layer.mask = gradientLayer
        }
    }

    @IBAction func pressedCloseButton() {
        self.dismiss(animated: true, completion: nil)
    }

    @IBAction func pressedMarkReadButton() {
        markReadAction?(self.reading)
    }

    func loadNextChunk() {
        self.spinner?.startAnimating() // TODO: only after scrolled all the way down
        self.isLoadingChunk = true

        BRReadingFetcher.fetchChunk(self.loadedChunks + 1, forReading: self.reading!) { (data: [String: Any]) in
            let newText = attributedStringFromData(data)
            OperationQueue.main.addOperation {
                let readingText = NSMutableAttributedString(attributedString: self.textView!.attributedText)
                readingText.append(newText)
                self.spinner?.stopAnimating()
                self.textView?.attributedText = readingText

                self.loadedChunks += 1
                self.isLoadingChunk = false
            }
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if self.isLoadingChunk { return }
        if self.loadedChunks == self.totalChunks { return }
        if scrollView.contentSize.height < (self.textView?.frame.size.height ?? 10000) { return }
        if scrollView.contentOffset.y < scrollView.contentSize.height/2 { return }
        self.loadNextChunk()
    }
}

fileprivate func attributedStringFromData(_ data: [String: Any], verseIds: [String]? = nil) -> NSAttributedString {
    let readingText: NSMutableAttributedString = NSMutableAttributedString(string: "")
    if verseIds != nil {
        print(verseIds!, "\n", data)
    }

    if let chapterTitle = data["reference"] as? String {
        readingText.append(NSAttributedString(string: chapterTitle + "\n\n", attributes: chapterAttributes))
    }
    if let content = data["content"] as? Array<Any> {
        for c in content {
            var wroteAnything = false
            if let para = c as? [String: Any],
                let pname = para["name"] as? String,
                pname == "para",
                let items = para["items"] as? [Any] {
                var verseNumber: String?
                for i in items {
                    if let item = i as? [String: Any] {
                        if let iname = item["name"] as? String,
                            iname == "verse",
                            let attrs = item["attrs"] as? [String: Any],
                            let verse = attrs["number"] as? String {
                            verseNumber = verse
                        }
                        else if let attrs = item["attrs"] as? [String: Any],
                            let verseId = attrs["verseId"] as? String,
                            let itag = item["type"] as? String,
                            itag == "text",
                            let text = item["text"] as? String {
                            if shouldUseVerse(verseId, goodVerseIds: verseIds) {
                                if verseNumber != nil {
                                    readingText.append(NSAttributedString(string: verseNumber! + " ", attributes: verseAttributes))
                                }
                                readingText.append(NSAttributedString(string: text + " ", attributes: textAttributes))
                                wroteAnything = true
                            }
                        }
                    }
                }
            }
            if wroteAnything {
                readingText.append(NSAttributedString(string: "\n\n", attributes: textAttributes))
            }
        }
    }
    readingText.append(NSAttributedString(string: "\n", attributes: textAttributes))

    return readingText
}

fileprivate func shouldUseVerse(_ verseId: String, goodVerseIds: [String]?) -> Bool {
    if goodVerseIds == nil {
        return true
    }
    for i in goodVerseIds! {
        if i == verseId {
            return true
        }
    }
    return false
}
