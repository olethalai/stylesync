//
//  StyleParser.swift
//  StyleSync
//
//  Created by Dylan Lewis on 23/08/2017.
//  Copyright © 2017 Dylan Lewis. All rights reserved.
//

import Foundation

struct StyleParser<S: Style> {
	var newStyles: [S]
	
	func deprecatedStyles(usingPreviouslyExportedStyles previouslyExportedStyles: [S]) -> [S] {
		return previouslyExportedStyles
			.filter { style -> Bool in
				return newStyles.contains(where: { $0.identifier == style.identifier }) == false
			}
			.map({ $0.deprecated })
			.flatMap({ $0 as? S })
	}
	
	func getCurrentAndMigratedStyles(usingPreviouslyExportedStyles previouslyExportedStyles: [S]) -> [(currentStyle: S, migratedStyle: S)] {
		return previouslyExportedStyles
			.flatMap { style -> (S, S)? in
				guard
					let migratedStyle = newStyles
						.first(where: { $0.identifier == style.identifier && $0.name != style.name })
				else {
					return nil
				}
				return (style, migratedStyle)
			}
	}
}
