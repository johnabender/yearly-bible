//
//  BRSettingsViewController.swift
//  bible-reading
//
//  Created by John Bender on 11/23/14.
//  Copyright (c) 2014 Bender Systems. All rights reserved.
//

import UIKit

class BRSettingsViewController: UIViewController, BRDatePickerDelegate {

    @IBOutlet var scheduleButton: UIButton?
    @IBOutlet var scheduleLabel: UILabel?

    @IBOutlet var orderControl: UISegmentedControl?
    @IBOutlet var topicalText: UITextView?
    @IBOutlet var sequentialText: UITextView?

    let desiredFlags = UIUserNotificationType.Sound | UIUserNotificationType.Alert

    override func viewDidLoad() {
        super.viewDidLoad()

        self.updateButtonTitle()
        self.updateExplanatoryText()
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func isSchedulePrefSet() -> Bool {
        return NSUserDefaults.standardUserDefaults().objectForKey(BRReadingSchedulePreference) != nil
    }

    func updateButtonTitle() {
        var wasSet = false
        if scheduleButton != nil {
            if self.isSchedulePrefSet() {
                if let savedDate: AnyObject = NSUserDefaults.standardUserDefaults().objectForKey(BRReadingSchedulePreference)? {
                    if let scheduleDate = savedDate as? NSDate {
                        wasSet = true
                        scheduleButton!.setTitle("Stop Reminders", forState: UIControlState.Normal)
                        let timeFormatter = NSDateFormatter()
                        timeFormatter.timeStyle = NSDateFormatterStyle.ShortStyle
                        let scheduleString = timeFormatter.stringFromDate(scheduleDate)
                        scheduleLabel!.text = NSString(format: "Daily at %@", scheduleString)
                    }
                }
            }
        }
        if !wasSet {
            scheduleButton!.setTitle("Schedule Reminders", forState: UIControlState.Normal)
            scheduleLabel!.text = ""
        }
    }

    @IBAction func pressedReminderButton() {
        if self.isSchedulePrefSet() {
            NSUserDefaults.standardUserDefaults().removeObjectForKey(BRReadingSchedulePreference)
            BRReadingManager.updateScheduledNotifications()
            self.updateButtonTitle()
        } else {
            let curSettings = UIApplication.sharedApplication().currentUserNotificationSettings()
            if curSettings.types & desiredFlags == UIUserNotificationType(0) {
                self.registerForNotifications()
            } else {
                self.scheduleReminder()
            }
        }
    }

    func registerForNotifications() {
        let category = UIMutableUserNotificationCategory()
        category.identifier = BRNotificationCategory
        let action = UIMutableUserNotificationAction()
        action.identifier = "BRMarkReadAction"
        action.title = "Mark Read"
        action.activationMode = UIUserNotificationActivationMode.Background
        category.setActions([action], forContext: UIUserNotificationActionContext.Default)
        category.setActions([action], forContext: UIUserNotificationActionContext.Minimal)
        let desiredCategories = NSSet().setByAddingObject(category)
        let newSettings = UIUserNotificationSettings(forTypes: desiredFlags, categories: desiredCategories)
        UIApplication.sharedApplication().registerUserNotificationSettings(newSettings)
    }

    func scheduleReminder() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc: AnyObject! = storyboard.instantiateViewControllerWithIdentifier("BRDatePicker")
        let datePickerVC = vc as BRDatePickerViewController
        datePickerVC.delegate = self
        self.presentViewController(datePickerVC, animated: true, completion: nil)
    }

    func datePickerSelectedDate(date: NSDate) {
        self.dismissViewControllerAnimated(true, completion: nil)
        NSUserDefaults.standardUserDefaults().setObject(date, forKey: BRReadingSchedulePreference)
        BRReadingManager.updateScheduledNotifications()
        self.updateButtonTitle()
    }

    @IBAction func changedOrderSelection() {
        BRReadingManager.setReadingType(BRReadingType(rawValue: orderControl!.selectedSegmentIndex)!)
        self.updateExplanatoryText()
    }

    func updateExplanatoryText() {
        switch BRReadingManager.readingType() {
        case .Sequential:
            topicalText!.hidden = true
            sequentialText!.hidden = false
            orderControl!.selectedSegmentIndex = 0 // should cast the readingType, but Swift
        case .Topical:
            topicalText!.hidden = false
            sequentialText!.hidden = true
            orderControl!.selectedSegmentIndex = 1
        }
    }
}
