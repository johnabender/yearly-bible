//
//  UIFont+Traits.swift
//  bible-reading
//
//  Created by John Bender on 1/3/19.
//  Copyright © 2019 Bender Systems. All rights reserved.
//

import UIKit

// https://stackoverflow.com/a/21777132
extension UIFont {
    var bold: UIFont {
        return with(traits: .traitBold)
    } // bold

    var italic: UIFont {
        return with(traits: .traitItalic)
    } // italic

    var boldItalic: UIFont {
        return with(traits: [.traitBold, .traitItalic])
    } // boldItalic


    func with(traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let descriptor = self.fontDescriptor.withSymbolicTraits(traits) else {
            Util.log("no font found for \(self.familyName)::\(self.fontName) with traits \(traits)")
            return self
        } // guard

        return UIFont(descriptor: descriptor, size: 0)
    } // with(traits:)
} // extension
