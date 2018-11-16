//
//  BRReadingViewController.swift
//  bible-reading
//
//  Created by John Bender on 11/13/18.
//  Copyright © 2018 Bender Systems. All rights reserved.
//

import UIKit

fileprivate let textFont = UIFont(name: "Gentium Basic", size: 17)!
fileprivate let textAttributes = [NSAttributedString.Key.font: textFont]
fileprivate let verseFont = UIFont(name: "KingThingsFoundation", size: 10)!
fileprivate let verseAttributes = [NSAttributedString.Key.font: verseFont,
                                   NSAttributedString.Key.baselineOffset: NSNumber(value: 5),
                                   NSAttributedString.Key.obliqueness: NSNumber(value: 0.1)]

class BRReadingViewController: UIViewController, UIScrollViewDelegate {

    @IBOutlet weak var contentView: UIView?
    @IBOutlet weak var dateLabel: UILabel?
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

        self.dateLabel?.text = self.reading?.passage
        self.markButton?.setTitle(BRMarkReadString, for: .normal)

        if self.reading != nil {
            BRReadingFetcher.fetchReading(self.reading!) { (data: [String: Any], versesToUse: [Any], totalChunks: Int) in
                self.totalChunks = totalChunks
                self.loadedChunks = 1
                self.isLoadingChunk = false

                let readingText = self.attributedStringFromData(data)
                OperationQueue.main.addOperation {
                    self.spinner?.stopAnimating()
                    self.spinnerCenterYConstraint?.constant = (self.textView?.frame.size.height ?? 0)/2 - (self.spinner?.frame.size.height ?? 0)
                    self.textView?.attributedText = readingText
                    self.textView?.isScrollEnabled = true
                }
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if self.contentView != nil && self.textView != nil {
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
        BRReadingFetcher.fetchChunk(self.loadedChunks + 1, forReading: self.reading!) { (data: [String: Any], versesToUse: [Any]) in
            self.loadedChunks += 1
            self.isLoadingChunk = false

            let readingText = NSMutableAttributedString(attributedString: self.textView!.attributedText)
            readingText.append(self.attributedStringFromData(data))
            OperationQueue.main.addOperation {
                self.spinner?.stopAnimating()
                self.textView?.attributedText = readingText
            }
        }
    }

    func attributedStringFromData(_ data: [String: Any]) -> NSAttributedString {
        let readingText: NSMutableAttributedString = NSMutableAttributedString(string: "")

        if let content = data["content"] as? Array<Any> {
            for c in content {
                if let para = c as? [String: Any],
                    let pname = para["name"] as? String,
                    pname == "para",
                    let items = para["items"] as? [Any] {
                    for i in items {
                        if let item = i as? [String: Any] {
                            if let iname = item["name"] as? String,
                                iname == "verse",
                                let attrs = item["attrs"] as? [String: Any],
                                let verse = attrs["number"] as? String {
                                readingText.append(NSAttributedString(string: verse + " ", attributes: verseAttributes))
                            }
                            else if let itag = item["type"] as? String,
                                itag == "text",
                                let text = item["text"] as? String {
                                readingText.append(NSAttributedString(string: text + " ", attributes: textAttributes))
                            }
                        }
                    }
                }
                readingText.append(NSAttributedString(string: "\n\n", attributes: textAttributes))
            }
        }
        readingText.append(NSAttributedString(string: "\n\n", attributes: textAttributes))

        return readingText
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if self.isLoadingChunk { return }
        if self.loadedChunks == self.totalChunks { return }
        if scrollView.contentSize.height < (self.textView?.frame.size.height ?? 10000) { return }
        if scrollView.contentOffset.y < scrollView.contentSize.height/2 { return }
        self.loadNextChunk()
    }
}
