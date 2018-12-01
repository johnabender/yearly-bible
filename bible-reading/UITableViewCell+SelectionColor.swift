//
//  UITableViewCell+SelectionColor.swift
//  bible-reading
//
//  Created by John Bender on 11/30/18.
//  Copyright © 2018 Bender Systems. All rights reserved.
//

// https://stackoverflow.com/a/45989908

import UIKit

extension UITableViewCell {
    @IBInspectable var selectionColor: UIColor {
        set {
            let view = UIView()
            view.backgroundColor = newValue
            self.selectedBackgroundView = view
        }
        get {
            return self.selectedBackgroundView?.backgroundColor ?? UIColor.clear
        }
    }
}
