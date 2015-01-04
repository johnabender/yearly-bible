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

    let desiredFlags = UIUserNotificationType.Sound | UIUserNotificationType.Alert

    override func viewDidLoad() {
        super.viewDidLoad()

        self.updateButtonTitle()
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
        if scheduleButton != nil {
            if self.isSchedulePrefSet() {
                scheduleButton!.setTitle("Stop Reminders", forState: UIControlState.Normal)

                if let savedDate: AnyObject = NSUserDefaults.standardUserDefaults().objectForKey(BRReadingSchedulePreference)? {
                    if let scheduleDate = savedDate as? NSDate {
                        let timeFormatter = NSDateFormatter()
                        timeFormatter.timeStyle = NSDateFormatterStyle.ShortStyle
                        let scheduleString = timeFormatter.stringFromDate(scheduleDate)
                        scheduleLabel!.text = NSString(format: "Daily at %@", scheduleString)
                    }
                }
            } else {
                scheduleButton!.setTitle("Schedule Reminders", forState: UIControlState.Normal)
                scheduleLabel!.text = ""
            }
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
}
