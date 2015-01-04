//
//  BRDatePickerViewController.swift
//  bible-reading
//
//  Created by John Bender on 1/3/15.
//  Copyright (c) 2015 Bender Systems. All rights reserved.
//

import UIKit

protocol BRDatePickerDelegate {
    func datePickerSelectedDate(date: NSDate)
}

class BRDatePickerViewController: UIViewController {

    var delegate : BRDatePickerDelegate? = nil

    @IBOutlet var datePicker: UIDatePicker?

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        if animated {
            self.view.backgroundColor = UIColor.clearColor()
            UIView.animateWithDuration(0.25, animations: { () -> Void in
                self.view.backgroundColor = UIColor.whiteColor()
            }, completion: nil)
        }
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)

        if animated {
            UIView.animateWithDuration(0.25, animations: { () -> Void in
                self.view.backgroundColor = UIColor.clearColor()
            }, completion: nil)
        }
    }

    @IBAction func pressedDoneButton() {
        if delegate != nil {
            delegate!.datePickerSelectedDate(datePicker!.date)
        }
    }
}
