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

    var delegate : BRDatePickerDelegate?

    @IBOutlet var bottomOffsetConstraint: NSLayoutConstraint?
    @IBOutlet var heightConstraint: NSLayoutConstraint?

    @IBOutlet var datePicker: UIDatePicker?

    func presentInView(view: UIView) {
        view.addSubview(self.view)
        view.addConstraints([NSLayoutConstraint(item: view, attribute: .Leading, relatedBy: .Equal, toItem: self.view, attribute: .Leading, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: view, attribute: .Trailing, relatedBy: .Equal, toItem: self.view, attribute: .Trailing, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: view, attribute: .Top, relatedBy: .Equal, toItem: self.view, attribute: .Top, multiplier: 1, constant: 0),
            NSLayoutConstraint(item: view, attribute: .Bottom, relatedBy: .Equal, toItem: self.view, attribute: .Bottom, multiplier: 1, constant: 0)])

        self.view.alpha = 0
        bottomOffsetConstraint?.constant = -heightConstraint!.constant
        self.view.layoutIfNeeded()

        UIView.animateWithDuration(0.3, animations: { () -> Void in
            self.view.alpha = 1
            self.bottomOffsetConstraint?.constant = 0
            self.view.layoutIfNeeded()
        })
    }

    func dismiss() {
        UIView.animateWithDuration(0.3, animations: { () -> Void in
            self.bottomOffsetConstraint?.constant = -self.heightConstraint!.constant
            self.view.alpha = 0
            self.view.layoutIfNeeded()
        }, completion: { (completed: Bool) -> Void in
            self.view.removeFromSuperview()
        })
    }

    @IBAction func pressedDoneButton() {
        delegate?.datePickerSelectedDate(datePicker!.date)
    }
}
