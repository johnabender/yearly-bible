//
//  BRReadingViewController.swift
//  bible-reading
//
//  Created by John Bender on 11/13/18.
//  Copyright © 2018 Bender Systems. All rights reserved.
//

import UIKit

fileprivate let chapterFont = UIFont(name: "KingThingsFoundation", size: 17) ?? UIFont.systemFont(ofSize: 17)
fileprivate var chapterAttributes: [NSAttributedString.Key: Any] = [.font: chapterFont]
fileprivate let textFont = UIFont(name: "Gentium Basic", size: 15) ?? UIFont.systemFont(ofSize: 15)
fileprivate var textAttributes: [NSAttributedString.Key: Any] = [.font: textFont]
fileprivate let verseFont = UIFont(name: "KingThingsFoundation", size: 10) ?? UIFont.systemFont(ofSize: 10)
fileprivate var verseAttributes: [NSAttributedString.Key: Any] = [.font: verseFont,
                                                                  .baselineOffset: NSNumber(value: 5),
                                                                  .obliqueness: NSNumber(value: 0.1)]
fileprivate var copyrightAttributes: [NSAttributedString.Key: Any] = [.font: textFont.italic]

class BRReadingViewController: UIViewController, UIScrollViewDelegate {

    @IBOutlet weak var blurView: UIVisualEffectView?

    @IBOutlet weak var contentView: UIView?
    @IBOutlet weak var markButton: UIButton?
    @IBOutlet weak var closeButton: UIButton?
    @IBOutlet weak var textView: UITextView?

    @IBOutlet weak var spinner: UIActivityIndicatorView?
    @IBOutlet weak var spinnerCenterYConstraint: NSLayoutConstraint?

    @objc var reading: BRReading?
    @objc var markReadAction: ((BRReading?) -> Void)?

    private var loadedChunks = 0
    private var totalChunks = 0
    private var isLoadingChunk = true
    private var copyright: String? = nil

    override func viewDidLoad() {
        super.viewDidLoad()

        chapterAttributes[.font] = UIFontMetrics.default.scaledFont(for: chapterFont)
        textAttributes[.font] = UIFontMetrics.default.scaledFont(for: textFont)
        verseAttributes[.font] = UIFontMetrics.default.scaledFont(for: verseFont)
        if self.markButton?.titleLabel?.font != nil {
            self.markButton!.titleLabel!.font = UIFontMetrics.default.scaledFont(for: self.markButton!.titleLabel!.font)
        }
        if self.closeButton?.titleLabel?.font != nil {
            self.closeButton!.titleLabel!.font = UIFontMetrics.default.scaledFont(for: self.closeButton!.titleLabel!.font)
        }

        var fontColor = UIColor.black
        switch BRReadingManager.readingViewType() {
        case .darkText:
            self.blurView?.effect = UIBlurEffect(style: .light)
        case .lightText:
            self.blurView?.effect = UIBlurEffect(style: .dark)
            fontColor = .white

            let brightenFactor = CGFloat(0.1)
            var h = CGFloat(0), s = CGFloat(0), v = CGFloat(0), a = CGFloat(0)
            self.spinner?.color.getHue(&h, saturation: &s, brightness: &v, alpha: &a)
            let brighterColor = UIColor(hue: h, saturation: max(s - brightenFactor, 0), brightness: min(v + brightenFactor, 1), alpha: a)
            self.spinner?.color = brighterColor
            self.markButton?.setTitleColor(brighterColor, for: .normal)
            self.closeButton?.setTitleColor(brighterColor, for: .normal)
        @unknown default:
            break
        }
        chapterAttributes[.foregroundColor] = fontColor
        textAttributes[.foregroundColor] = fontColor
        verseAttributes[.foregroundColor] = fontColor.withAlphaComponent(0.5)
        copyrightAttributes[.foregroundColor] = fontColor

        self.markButton?.setTitle(BRMarkReadString, for: .normal)

        if self.reading == nil { return }

        if self.reading!.read {
            self.markButton?.isHidden = true
        }

        BRReadingFetcher.fetchReading(self.reading!) { (connectionError: Bool, apiError: Bool, data: [String: Any], verseIds: [String]?, totalChunks: Int) in
            self.totalChunks = totalChunks
            self.loadedChunks = 1
            self.isLoadingChunk = false

            var errorText: String? = nil
            if connectionError {
                errorText = "Couldn't connect to the reading service. Check your Internet connection."
            }
            else if apiError {
                errorText = "Couldn't download this reading. It may not be included in the translation you've selected."
            }
            if errorText != nil {
                OperationQueue.main.addOperation {
                    let alert = UIAlertController(title: "Error", message: errorText, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action: UIAlertAction) in
                        self.dismiss(animated: true, completion: nil)
                    }))
                    self.present(alert, animated: true, completion: nil)
                }
            }

            let readingText = NSMutableAttributedString(string: "\n\n\n", attributes: textAttributes)
            readingText.append(self.attributedStringFromData(data, verseIds: verseIds))
            if self.totalChunks == 1 {
                readingText.append(NSAttributedString(string: "\n\n", attributes: textAttributes))
                if self.copyright != nil {
                    readingText.append(NSAttributedString(string: "Copyright: \(self.copyright!)\n\n\n", attributes: copyrightAttributes))
                }
            }

            OperationQueue.main.addOperation {
                self.spinner?.stopAnimating()
                self.spinnerCenterYConstraint?.constant = (self.textView?.frame.size.height ?? 0)/2 - 2*(self.spinner?.frame.size.height ?? 0)
                self.textView?.attributedText = readingText
                self.textView?.isScrollEnabled = true
                
                self.checkToLoadNextChunk()
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        OperationQueue.main.addOperation {
            if let contentView = self.contentView, let textView = self.textView {
                let gradientSize = CGFloat(0.1) // fraction of contentView's height
                let gradientLayer = CAGradientLayer()
                gradientLayer.frame = contentView.bounds
                let topTopOffset = (textView.frame.origin.y - 2)/contentView.bounds.size.height
                let topBottomOffset = topTopOffset + gradientSize
                let topTopCoordinate = NSNumber(value: Double(topTopOffset))
                let topBottomCoordinate = NSNumber(value: Double(topBottomOffset))
                let bottomBottomOffset = (textView.frame.size.height + textView.frame.origin.y + 1)/contentView.bounds.size.height
                let bottomTopOffset = bottomBottomOffset - gradientSize
                let bottomBottomCoordinate = NSNumber(value: Double(bottomBottomOffset))
                let bottomTopCoordinate = NSNumber(value: Double(bottomTopOffset))
                gradientLayer.locations = [topTopCoordinate, topTopCoordinate, topBottomCoordinate, bottomTopCoordinate, bottomBottomCoordinate, bottomBottomCoordinate]
                gradientLayer.colors = [UIColor.white.cgColor, UIColor.clear.cgColor, UIColor.white.cgColor, UIColor.white.cgColor, UIColor.clear.cgColor, UIColor.white.cgColor]
                contentView.layer.mask = gradientLayer
            }
        }
    }

    @IBAction func pressedCloseButton() {
        self.dismiss(animated: true, completion: nil)
    }

    @IBAction func pressedMarkReadButton() {
        markReadAction?(self.reading)
        self.markButton?.isHidden = true
    }

    func checkToLoadNextChunk() {
        // start loading next chunk without scroll, if content isn't long enough to scroll
        if let cs = self.textView?.contentSize.height,
            let fs = self.textView?.frame.size.height,
            cs <= fs,
            self.totalChunks > self.loadedChunks {
            self.loadNextChunk()
        }
    }

    func loadNextChunk() {
        self.isLoadingChunk = true

        BRReadingFetcher.fetchChunk(self.loadedChunks + 1, forReading: self.reading!) { (data: [String: Any]) in
            let newText = self.attributedStringFromData(data)
            OperationQueue.main.addOperation {
                self.loadedChunks += 1
                self.isLoadingChunk = false

                let readingText = NSMutableAttributedString(attributedString: self.textView!.attributedText)
                readingText.append(newText)
                if self.loadedChunks == self.totalChunks {
                    readingText.append(NSAttributedString(string: "\n\n", attributes: textAttributes))
                    if self.copyright != nil {
                        readingText.append(NSAttributedString(string: "Copyright: \(self.copyright!)\n\n\n", attributes: copyrightAttributes))
                    }
                }

                self.spinner?.stopAnimating()
                self.textView?.attributedText = readingText

                self.checkToLoadNextChunk()
            }
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if self.loadedChunks == self.totalChunks { return }
        if scrollView.contentSize.height < scrollView.frame.size.height { return }
        if (scrollView.contentSize.height - scrollView.contentOffset.y - scrollView.frame.size.height) > scrollView.frame.size.height/2 { return }
        if self.isLoadingChunk {
            if self.spinner != nil, self.spinner!.isAnimating { return }
            if (scrollView.contentSize.height - scrollView.contentOffset.y - scrollView.frame.size.height) < 100 {
                self.spinner?.startAnimating()
            }
        }
        else {
            self.loadNextChunk()
        }
    }

    private func attributedStringFromData(_ data: [String: Any], verseIds: [String]? = nil) -> NSAttributedString {
        let readingText: NSMutableAttributedString = NSMutableAttributedString(string: "")

//        Util.log("\(data)")
        if let copyrightText = data["copyright"] as? String {
            self.copyright = copyrightText // storing globally assumes it's effectively constant
        }
        if let chapterTitle = data["reference"] as? String {
            readingText.append(NSAttributedString(string: chapterTitle + "\n\n", attributes: chapterAttributes))
        }
        if var content = data["content"] as? NSString {
            // replace random garbage in text strings
            content = content.replacingOccurrences(of: " ¶ ", with: " ") as NSString
            content = content.replacingOccurrences(of: "¶", with: " ") as NSString
            content = content.replacingOccurrences(of: "  ", with: " ") as NSString
            content = content.replacingOccurrences(of: "[Selah", with: "Selah") as NSString

            var nextVerseHeader = content.range(of: "\\[\\d+\\]", options: .regularExpression)
            var currentVerse = "1"
            var shouldUseCurrentVerse = shouldUseVerse(currentVerse, goodVerseIds: verseIds)
            while nextVerseHeader.location != NSNotFound {
                if shouldUseCurrentVerse {
                    let text = content.substring(to: nextVerseHeader.location)
                    readingText.append(NSAttributedString(string: text, attributes: textAttributes))
                }

                currentVerse = content.substring(with: NSRange(location: nextVerseHeader.location + 1, length: nextVerseHeader.length - 2))
                shouldUseCurrentVerse = shouldUseVerse(currentVerse, goodVerseIds: verseIds)
                if shouldUseCurrentVerse {
                    readingText.append(NSAttributedString(string: currentVerse, attributes: verseAttributes))
                }

                content = content.substring(from: nextVerseHeader.location + nextVerseHeader.length + 1) as NSString
                nextVerseHeader = content.range(of: "\\[\\d+\\]", options: .regularExpression)
            }
            if shouldUseCurrentVerse {
                readingText.append(NSAttributedString(string: content as String, attributes: textAttributes))
            }
        }
        /* change ReadingFetcher API call from text to json content-type
         misses added words, chapter titles (Psalms), "Selah" tags, double-labels some verses
         see GEN.1, PS.1, LAM.4 (json in repo) */
        /*else if let content = data["content"] as? [Any] {
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
                                        readingText.append(NSAttributedString(string: verseNumber!, attributes: verseAttributes))
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
        }*/
        readingText.append(NSAttributedString(string: "\n", attributes: textAttributes))


        return readingText
    }
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
