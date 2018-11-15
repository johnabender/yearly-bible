//
//  BRReadingViewController.swift
//  bible-reading
//
//  Created by John Bender on 11/13/18.
//  Copyright © 2018 Bender Systems. All rights reserved.
//

import UIKit

class BRReadingViewController: UIViewController {

    @IBOutlet weak var contentView: UIView?
    @IBOutlet weak var dateLabel: UILabel?
    @IBOutlet weak var markButton: UIButton?
    @IBOutlet weak var textView: UITextView?

    @objc var reading: BRReading?
    @objc var markReadAction: ((BRReading?) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()

        self.dateLabel?.text = self.reading?.passage
        self.markButton?.setTitle(BRMarkReadString, for: .normal)

        if self.reading != nil {
            BRReadingFetcher.fetchReading(self.reading!) { (data: [String: Any]) in
                let readingText: NSMutableAttributedString = NSMutableAttributedString(string: "")
                let textFont = UIFont(name: "Gentium Basic", size: 17)!
                let textAttributes = [NSAttributedString.Key.font: textFont]
                let verseFont = UIFont(name: "KingThingsFoundation", size: 10)!
                let verseAttributes = [NSAttributedString.Key.font: verseFont,
                                       NSAttributedString.Key.obliqueness: NSNumber(value: 0)]

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
                                        readingText.append(NSAttributedString(string: "\n", attributes: textAttributes))
                                        readingText.append(NSAttributedString(string: verse, attributes: verseAttributes))
                                    }
                                    else if let itag = item["type"] as? String,
                                        itag == "text",
                                        let text = item["text"] as? String {
                                        readingText.append(NSAttributedString(string: " " + text, attributes: textAttributes))
                                    }
                                }
                            }
                        }
                        readingText.append(NSAttributedString(string: "\n", attributes: textAttributes))
                    }
                }
                readingText.append(NSAttributedString(string: "\n\n", attributes: textAttributes))

                OperationQueue.main.addOperation {
                    self.textView?.attributedText = readingText
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
}
