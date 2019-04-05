//
//  BRSettingsViewController.swift
//  bible-reading
//
//  Created by John Bender on 11/23/14.
//  Copyright (c) 2014 Bender Systems. All rights reserved.
//

import UIKit
import UserNotifications

class BRSettingsViewController: UITableViewController, BRDatePickerDelegate {

    @IBOutlet var versionLabel: UIBarButtonItem?

    @IBOutlet var scheduleButton: UIButton?
    @IBOutlet var scheduleLabel: UILabel?

    @IBOutlet var orderControl: UISegmentedControl?

    @IBOutlet var readingDisplayControl: UISegmentedControl?
    @IBOutlet var translationLabel: UILabel?

    var datePickerVC: BRDatePickerViewController?

    class func smallFont() -> UIFont { return UIFont(name: "Gentium Basic", size:15.0)! }
    class func largeFont() -> UIFont { return UIFont(name: "Gentium Basic", size:17.0)! }
    class func textColor() -> UIColor { return UIColor(red: 108.0/255.0, green: 94.0/255.0, blue: 68.0/255.0, alpha: 1) }

    override func viewDidLoad() {
        super.viewDidLoad()

        versionLabel?.title = String(format: "v%@ (%@)", Bundle.main.releaseVersionNumber!, Bundle.main.buildVersionNumber!)
        let versionColor = BRSettingsViewController.textColor().withAlphaComponent(0.5)
        versionLabel?.setTitleTextAttributes([.foregroundColor: versionColor], for: .disabled)

        self.tableView.backgroundView = UIImageView(image: UIImage(named: "bg"))

        self.updateButtonTitle()

        orderControl?.setTitleTextAttributes([.font: BRSettingsViewController.largeFont()], for: .normal)
        switch BRReadingManager.readingType() {
        case .sequential:
            orderControl?.selectedSegmentIndex = 0 // should cast the readingType, but Swift
        case .topical:
            orderControl?.selectedSegmentIndex = 1
        }

        readingDisplayControl?.setTitleTextAttributes([.font: BRSettingsViewController.largeFont()], for: .normal)
        switch BRReadingManager.readingViewType() {
        case .darkText:
            readingDisplayControl?.selectedSegmentIndex = 0
        case .lightText:
            readingDisplayControl?.selectedSegmentIndex = 1
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.updateTranslationLabel()
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        header.textLabel?.font = BRSettingsViewController.largeFont().withSize(20)
        header.textLabel?.textColor = .black
    }

    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        if section == tableView.numberOfSections - 1 {
            OperationQueue.main.addOperation {
                self.changedOrderSelection()
            }
        }
        else {
            guard let footer = view as? UITableViewHeaderFooterView else { return }
            footer.textLabel?.font = BRSettingsViewController.smallFont()
            footer.textLabel?.textColor = BRSettingsViewController.textColor()
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 1:
            return "For each reading, press and hold to display the verses."
        case tableView.numberOfSections - 1:
            switch BRReadingManager.readingType() {
            case .sequential:
                return "Swipe each day's reading left to mark it as read, or right to mark it unread."
            case .topical:
                return """
                Swipe each day's reading left to mark it as read, or right to mark it unread.

                The topical reading order divides the Bible into seven sections, one for each day of the week. If January 1 were a Monday, the days would be as follows:

                Monday: Law (Gen. - Deut.)
                Tuesday: History (Joshua - Esther)
                Wednesday: Psalms
                Thursday: Poetry (Job, Prov. - Song)
                Friday: Prophecy (Isaiah - Malachi)
                Saturday: Gospels (Matt. - Acts)
                Sunday: Letters (Romans - Rev.)

                Dividing the Bible into topical sections provides variety from day to day in both the type of each day's content and its length. This helps avoid boredom and also allows one to catch up more easily if a day is missed, by combining two shorter readings together to make up for the lost day.

                The daily divisions have been tuned over the course of several years for both consistency and contiguity. Within a section, each day’s reading is approximately the same length throughout the year, subject to a few caveats. None of the chapters are broken across days (other than Psalm 119), and related neighboring chapters are kept together if practical. In general, drier sections of text, such as descriptions of the tabernacle or genealogies, are conglomerated into longer daily readings, while more poetic or narrative text, such as the psalms or the travels of the patriarchs, are separated for more individual attention.
                """
            }
        default:
            return nil
        }
    }

    func updateButtonTitle() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        if BRReadingManager.isReadingScheduleSet(),
            let savedDate = dateFormatter.date(from: BRReadingManager.readingSchedule()) {

            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = DateFormatter.Style.short
            let scheduleString = timeFormatter.string(from: savedDate)
            scheduleLabel?.text = String(format: "daily at %@", scheduleString)
            scheduleButton?.setTitle("Stop reminders", for: UIControl.State.normal)
        }
        else {
            scheduleButton?.setTitle("Schedule reminders", for: UIControl.State.normal)
            scheduleLabel?.text = ""
        }
    }

    @IBAction func pressedReminderButton() {
        if BRReadingManager.isReadingScheduleSet() {
            BRReadingManager.setReadingSchedule(nil)
            BRReadingManager.updateScheduledNotifications()
            self.updateButtonTitle()
        } else {
            UNUserNotificationCenter.current().getNotificationSettings { (settings) in
                switch settings.authorizationStatus {
                case .notDetermined:
                    self.registerForNotifications()
                case .authorized:
                    DispatchQueue.main.async {
                        self.scheduleReminder()
                    }
                default:
                    break
                }
            }
        }
    }

    func updateTranslationLabel() {
        if let translation = BRReadingManager.preferredTranslation() {
            translationLabel?.text = translation.name
        }
    }

    func registerForNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.sound, .alert]) { (granted: Bool, error: Error?) in
            if granted && error == nil {
                DispatchQueue.main.async {
                    self.pressedReminderButton()
                }
            }
        }
    }

    func scheduleReminder() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc: AnyObject! = storyboard.instantiateViewController(withIdentifier: "BRDatePicker")
        datePickerVC = vc as? BRDatePickerViewController
        datePickerVC?.delegate = self
        datePickerVC?.presentInView(view: self.navigationController!.view)
    }

    func datePickerSelectedDate(date: NSDate) {
        datePickerVC?.dismiss()
        datePickerVC = nil

        BRReadingManager.setReadingScheduleWith(date as Date)
        BRReadingManager.updateScheduledNotifications()
        self.updateButtonTitle()
    }

    @IBAction func changedOrderSelection() {
        BRReadingManager.setReadingType(BRReadingType(rawValue: orderControl!.selectedSegmentIndex)!)

        let lastSection = self.tableView.numberOfSections - 1
        if let label = self.tableView.footerView(forSection: lastSection)?.textLabel {
            /*
             let animation = CATransition()
             animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
             animation.type = .fade
             animation.duration = 0.3
             label.layer.add(animation, forKey: "kCATransitionFade")
 */
            label.text = self.tableView(self.tableView, titleForFooterInSection: lastSection)
            label.font = BRSettingsViewController.smallFont()
            label.textColor = BRSettingsViewController.textColor()
            label.sizeToFit()

            var height = CGFloat(10*self.tableView.numberOfSections)
            for s in 0..<self.tableView.numberOfSections {
                height += self.tableView.headerView(forSection: s)?.frame.size.height ?? self.tableView.sectionHeaderHeight
                for _ in 0..<self.tableView.numberOfRows(inSection: s) {
                    height += self.tableView.rowHeight
                }
                if s < self.tableView.numberOfSections - 1 {
                    height += self.tableView.footerView(forSection: s)?.frame.size.height ?? self.tableView.sectionFooterHeight
                }
                else {
                    height += label.frame.size.height
                }
            }

            self.tableView.contentSize = CGSize(width: self.tableView.contentSize.width, height: height)
            if self.tableView.contentSize.height < self.tableView.frame.size.height - self.tableView.safeAreaInsets.top - self.tableView.safeAreaInsets.bottom {
                self.tableView.isScrollEnabled = false
            }
            else {
                self.tableView.isScrollEnabled = true
            }
        }
    }

    @IBAction func changedReadingDisplaySelection() {
        BRReadingManager.setReadingViewType(BRReadingViewType(rawValue: readingDisplayControl!.selectedSegmentIndex)!)
    }
}
