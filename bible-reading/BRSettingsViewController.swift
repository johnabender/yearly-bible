//
//  BRSettingsViewController.swift
//  bible-reading
//
//  Created by John Bender on 11/23/14.
//  Copyright (c) 2014 Bender Systems. All rights reserved.
//

import UIKit
import UserNotifications

fileprivate let smallFont = UIFont(name: "Gentium Basic", size:15.0)!
fileprivate let largeFont = UIFont(name: "Gentium Basic", size:17.0)!
fileprivate let textColor = UIColor(red: 108.0/255.0, green: 94.0/255.0, blue: 68.0/255.0, alpha: 1)

class BRSettingsViewController: UITableViewController, BRDatePickerDelegate {

    @IBOutlet var versionLabel: UIBarButtonItem?

    @IBOutlet var backgroundView: UIImageView?

    @IBOutlet var scheduleButton: UIButton?
    @IBOutlet var scheduleLabel: UILabel?

    @IBOutlet var orderControl: UISegmentedControl?

    @IBOutlet var readingDisplayControl: UISegmentedControl?
    @IBOutlet var translationLabel: UILabel?

    var datePickerVC: BRDatePickerViewController?

    override func viewDidLoad() {
        super.viewDidLoad()

        versionLabel?.title = String(format: "v%@ (%@)", Bundle.main.releaseVersionNumber!, Bundle.main.buildVersionNumber!)
        let versionColor = textColor.withAlphaComponent(0.5)
        versionLabel?.setTitleTextAttributes([.foregroundColor: versionColor], for: .disabled)

        self.backgroundView?.removeFromSuperview()
        self.tableView.backgroundView = self.backgroundView

        self.updateButtonTitle()

        orderControl?.setTitleTextAttributes([.font: largeFont], for: .normal)
        switch BRReadingManager.readingType() {
        case .sequential:
            orderControl?.selectedSegmentIndex = 0 // should cast the readingType, but Swift
        case .topical:
            orderControl?.selectedSegmentIndex = 1
        }

        readingDisplayControl?.setTitleTextAttributes([.font: largeFont], for: .normal)
        switch BRReadingManager.readingViewType() {
        case .darkText:
            readingDisplayControl?.selectedSegmentIndex = 0
        case .lightText:
            readingDisplayControl?.selectedSegmentIndex = 1
        }
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        header.textLabel?.font = largeFont
        header.textLabel?.textColor = textColor
    }

    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        if section == tableView.numberOfSections - 1 {
            OperationQueue.main.addOperation {
                self.changedOrderSelection()
            }
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section != tableView.numberOfSections - 1 { return nil }

        switch BRReadingManager.readingType() {
        case .sequential:
            return "This app provides a list of daily readings for completing the entire Bible each year. The readings are presented as a checklist to aid in tracking progress - simply swipe each day left to mark it as read, or right to mark it unread."
        case .topical:
            return """
            This app provides a list of daily readings for completing the entire Bible each year. The readings are presented as a checklist to aid in tracking progress - simply swipe each day left to mark it as read, or right to mark it unread.

            This list of readings divides the Bible into seven sections, one for each day of the week. If January 1 were a Monday, the days would be as follows:

            Monday: Law (Gen. - Deut.)
            Tuesday: History (Joshua - Esther)
            Wednesday: Psalms
            Thursday: Poetry (Job, Prov. - Song)
            Friday: Prophecy (Isaiah - Malachi)
            Saturday: Gospels (Matt. - Acts)
            Sunday: Letters (Romans - Rev.)

            Thus, if one were to read all the Mondays, then all the Tuesdays, then all the Wednesdays, etc., it would be roughly the equivalent of reading the Bible straight through. However, dividing it into sections provides variety from day to day in both the type of content and its length. This helps avoid boredom and also allows one to catch up more easily if a day is missed, by combining two shorter readings together to make up for the lost day.

            The daily divisions have been tuned over the course of several years for both consistency and contiguity. Within a section, each day’s reading is approximately the same length throughout the year, subject to a few caveats. None of the chapters are broken across days (other than Psalm 119), and related neighboring chapters are kept together if practical. In general, drier sections of text, such as descriptions of the tabernacle or genealogies, are conglomerated into longer daily readings, while more poetic or narrative text, such as the psalms or the travels of the patriarchs, are separated for more individual attention.
            """
        }
    }

    func updateButtonTitle() {
        var wasSet = false
        if scheduleButton != nil {
            if BRReadingManager.isReadingScheduleSet() {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "HH:mm"
                if let savedDate = dateFormatter.date(from: BRReadingManager.readingSchedule()) {
                    wasSet = true
                    let timeFormatter = DateFormatter()
                    timeFormatter.timeStyle = DateFormatter.Style.short
                    let scheduleString = timeFormatter.string(from: savedDate)
                    scheduleLabel!.text = String(format: "daily at %@", scheduleString)
                    scheduleButton!.setTitle("Stop reminders", for: UIControl.State.normal)
                }
            }
        }
        if !wasSet {
            scheduleButton!.setTitle("Schedule reminders", for: UIControl.State.normal)
            scheduleLabel!.text = ""
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
            label.font = smallFont
            label.textColor = textColor
            label.sizeToFit()

            var height = CGFloat(10*self.tableView.numberOfSections)
            for s in 0..<self.tableView.numberOfSections {
                height += self.tableView.headerView(forSection: s)?.frame.size.height ?? self.tableView.sectionHeaderHeight
                for _ in 0..<self.tableView.numberOfRows(inSection: s) {
                    height += self.tableView.rowHeight
                }
            }
            height += label.frame.size.height
            self.tableView.contentSize = CGSize(width: self.tableView.contentSize.width, height: height)
        }
    }

    @IBAction func changedReadingDisplaySelection() {
        BRReadingManager.setReadingViewType(BRReadingViewType(rawValue: readingDisplayControl!.selectedSegmentIndex)!)
    }
}
