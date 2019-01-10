//
//  Util.swift
//  s3watcher
//
//  Created by John Bender on 5/1/17.
//  Copyright © 2017 Bender Systems, LLC. All rights reserved.
//

import Foundation

class Util: Any {
    static let dateFormatter = DateFormatter()

    class func log(_ string: String = "", file: String = #file, function: String = #function, line: Int = #line) {
#if DEBUG
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
        print("[\(dateFormatter.string(from: Date())) \((file as NSString).lastPathComponent):\(function):\(line)] \(string)")
#endif
    }
}
