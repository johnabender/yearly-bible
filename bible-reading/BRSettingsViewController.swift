//
//  BRSettingsViewController.swift
//  bible-reading
//
//  Created by John Bender on 11/23/14.
//  Copyright (c) 2014 Bender Systems. All rights reserved.
//

import UIKit
import UserNotifications

class BRSettingsViewController: UIViewController, BRDatePickerDelegate {

    @IBOutlet var scheduleButton: UIButton?
    @IBOutlet var scheduleLabel: UILabel?

    @IBOutlet var orderControl: UISegmentedControl?
    @IBOutlet var topicalText: UITextView?
    @IBOutlet var sequentialText: UITextView?

    @IBOutlet var versionLabel: UIBarButtonItem?

    var datePickerVC: BRDatePickerViewController?

    override func viewDidLoad() {
        super.viewDidLoad()

        let font = UIFont(name: "Gentium Basic", size:15.0)!
        orderControl?.setTitleTextAttributes([NSAttributedString.Key.font: font], for: .normal)

        versionLabel?.title = String(format: "v%@ (%@)", Bundle.main.releaseVersionNumber!, Bundle.main.buildVersionNumber!)

        self.updateButtonTitle()
        self.updateExplanatoryText()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        self.topicalText?.setContentOffset(.zero, animated: false)
        self.sequentialText?.setContentOffset(.zero, animated: false)
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
                    scheduleLabel!.text = String(format: "Daily at %@", scheduleString)
                    scheduleButton!.setTitle("Stop Reminders", for: UIControl.State.normal)
                }
            }
        }
        if !wasSet {
            scheduleButton!.setTitle("Schedule Reminders", for: UIControl.State.normal)
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
        self.updateExplanatoryText()
    }

    func updateExplanatoryText() {
        switch BRReadingManager.readingType() {
        case .sequential:
            topicalText!.isHidden = true
            sequentialText!.isHidden = false
            orderControl!.selectedSegmentIndex = 0 // should cast the readingType, but Swift
        case .topical:
            topicalText!.isHidden = false
            sequentialText!.isHidden = true
            orderControl!.selectedSegmentIndex = 1
        }
    }
}
