//
//  Bundle+VersionNumber.swift
//  dice-fairness
//
//  Created by John Bender on 4/11/18.
//  Copyright © 2018 Bender Systems. All rights reserved.
//

// https://stackoverflow.com/a/29978300

import Foundation

public extension Bundle {
	
	var releaseVersionNumber: String? {
		return infoDictionary?["CFBundleShortVersionString"] as? String
	}
	
	var buildVersionNumber: String? {
		return infoDictionary?["CFBundleVersion"] as? String
	}
}
