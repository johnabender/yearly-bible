//
//  BRTranslationListViewController.swift
//  bible-reading
//
//  Created by John Bender on 11/29/18.
//  Copyright © 2018 Bender Systems. All rights reserved.
//

import UIKit

class BRTranslationListViewController: UITableViewController {

    @IBOutlet var backgroundView: UIImageView?

    var preferredTranslation = BRReadingManager.preferredTranslation()
    var selectedCell: UITableViewCell?

    var englishBibles: [BRTranslation] = []
    var allOtherBibles: [String: [BRTranslation]] = [:]
    var languages: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView.backgroundView = UIImageView(image: UIImage(named: "bg"))

        let path = "v1/bibles"
        guard let biblesUrl = URL(string: path, relativeTo: BRReadingFetcher.baseUrl()) else { return }
        print(biblesUrl.absoluteString)

        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["api-key": BRReadingFetcher.apiKey()]
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
                let dict = json as? [String: Any],
                let dataArr = dict["data"] as? [Any] {
                for bibleObj in dataArr {
                    guard let bible = bibleObj as? [String: Any] else {
                        print("couldn't cast bible object to dictionary", bibleObj)
                        continue
                    }
                    guard let langObj = bible["language"] as? [String: Any] else {
                        print("couldn't cast language object to dictionary", bible)
                        continue
                    }
                    if let bibleId = bible["id"] as? String,
                        let bibleName = bible["name"] as? String,
                        let bibleDesc = bible["description"] as? String,
                        let langId = langObj["id"] as? String,
                        let langName = langObj["name"] as? String,
                        let langDirection = langObj["scriptDirection"] as? String,
                        langDirection == "LTR" {

                        let translation = BRTranslation()
                        translation.name = bibleName
                        translation.version = bibleDesc
                        translation.language = langName
                        translation.key = bibleId

                        if langId == "eng" {
                            self.englishBibles.append(translation)
                        }
                        else {
                            if self.allOtherBibles[langName] == nil {
                                self.allOtherBibles[langName] = [translation]
                                self.languages.append(langName)
                            }
                            else {
                                self.allOtherBibles[langName]!.append(translation)
                            }
                        }
                    }
                }
                self.languages = self.languages.sorted()
                OperationQueue.main.addOperation {
                    self.tableView.reloadData()
                }
            }
        }
        task.resume()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2 + allOtherBibles.count // notes + English + all others
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 { // notes
            if englishBibles.count > 0 {
                return 1
            }
            return 2
        }
        else if section == 1 { // English
            return englishBibles.count
        }
        else {
            return allOtherBibles[languages[section - 2]]!.count
        }
    }

    /*override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        var titles = Array(languages) // all others
        titles.insert("", at: 0) // notes
        if englishBibles.count > 0 {
            titles.insert("English", at: 1) // English
        }

        var indices: [String] = []
        for title in titles {
            indices.append(String(title.prefix(3)))
        }

        return indices
    }*/

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 { // notes
            return nil
        }
        if section == 1 { // English
            if englishBibles.count > 0 {
                return "English"
            }
            return nil
        }
        return languages[section - 2] // all others
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 { return 1 }
        return tableView.sectionHeaderHeight
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 { // notes
            if indexPath.row == 0 {
                return tableView.dequeueReusableCell(withIdentifier: "notesCell", for: indexPath)
            }
            return tableView.dequeueReusableCell(withIdentifier: "spinnerCell", for: indexPath)
        }

        var translation = BRTranslation()
        if indexPath.section == 1 { // English
            translation = englishBibles[indexPath.row]
        }
        else { // all others
            translation = allOtherBibles[languages[indexPath.section - 2]]![indexPath.row]
        }

        var cell = tableView.dequeueReusableCell(withIdentifier: "translationDetailCell", for: indexPath)
        if translation.version == "common" || translation.version == "Common" || translation.version == "commo" || translation.version == "Bible" || translation.version == translation.name {
            cell = tableView.dequeueReusableCell(withIdentifier: "translationCell", for: indexPath)
        }
        else {
            cell.detailTextLabel?.text = translation.version
        }

        cell.textLabel?.text = translation.name

        if translation.key == preferredTranslation?.key {
            cell.accessoryType = .checkmark
            selectedCell = cell
        }
        else {
            cell.accessoryType = .none
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 { return 60.0 }
        return tableView.rowHeight
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        header.textLabel?.font = BRSettingsViewController.largeFont().withSize(20)
        header.textLabel?.textColor = .black
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        selectedCell?.accessoryType = .none

        guard let cell = tableView.cellForRow(at: indexPath) else { return }
        cell.accessoryType = .checkmark
        selectedCell = cell

        if indexPath.section == 1 { // English
            for translation in englishBibles {
                if translation.name == cell.textLabel?.text,
                    (cell.detailTextLabel?.text == translation.version || cell.detailTextLabel == nil) {
                    print(translation)
                    preferredTranslation = translation
                    BRReadingManager.setPreferredTranslation(translation)
                }
            }
        }
        else { // all others
            if let language = self.tableView(self.tableView, titleForHeaderInSection: indexPath.section),
                let bibles = allOtherBibles[language] {
                for translation in bibles {
                    if translation.name == cell.textLabel?.text,
                        (cell.detailTextLabel?.text == translation.version || cell.detailTextLabel == nil) {
                        print(translation)
                        preferredTranslation = translation
                        BRReadingManager.setPreferredTranslation(translation)
                    }
                }
            }
        }
    }
}
