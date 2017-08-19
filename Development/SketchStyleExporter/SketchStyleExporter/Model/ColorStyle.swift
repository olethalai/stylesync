//
//  ColorStyle.swift
//  SketchStyleExporter
//
//  Created by Dylan Lewis on 10/08/2017.
//  Copyright © 2017 Dylan Lewis. All rights reserved.
//

import Cocoa

struct ColorStyle: CodeNameable {
	let name: String
	let identifier: String
	let color: NSColor
	
	init?(colorStyleObject: SketchDocument.ColorStyles.Object) {
		guard let colorFill = colorStyleObject.value.fills.first else {
			return nil
		}
		let red = colorFill.color.red
		let green = colorFill.color.green
		let blue = colorFill.color.blue
		let alpha = colorFill.color.alpha
		
		self.name = colorStyleObject.name
		self.identifier = colorStyleObject.identifier
		self.color = NSColor(red: red, green: green, blue: blue, alpha: alpha)
	}
}

// MARK: - Codable

extension ColorStyle: Codable {
	enum CodingKeys: String, CodingKey {
		case name, identifier, red, green, blue, alpha
	}
	
	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let red = try container.decode(CGFloat.self, forKey: .red)
		let green = try container.decode(CGFloat.self, forKey: .green)
		let blue = try container.decode(CGFloat.self, forKey: .blue)
		let alpha = try container.decode(CGFloat.self, forKey: .alpha)
		
		self.name = try container.decode(String.self, forKey: .name)
		self.identifier = try container.decode(String.self, forKey: .identifier)
		self.color = NSColor(red: red/255, green: green/255, blue: blue/255, alpha: alpha)
	}
	
	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(name, forKey: .name)
		try container.encode(identifier, forKey: .identifier)
		try container.encode(color.redComponent*255, forKey: .red)
		try container.encode(color.greenComponent*255, forKey: .green)
		try container.encode(color.blueComponent*255, forKey: .blue)
		try container.encode(color.alphaComponent, forKey: .alpha)
	}
}

// MARK: - Equatable

extension ColorStyle: Equatable {
	static func == (lhs: ColorStyle, rhs: ColorStyle) -> Bool {
		return
			lhs.name == rhs.name &&
			lhs.identifier == rhs.identifier &&
			lhs.color == rhs.color
	}
}

// MARK: - CodeTemplateReplacable

extension ColorStyle: CodeTemplateReplacable {
	static let declarationName: String = "colorDeclaration"
	
	var replacementDictionary: [String: String] {
		return [
			"name": name,
			"colorName": codeName,
			"red": String(describing: color.redComponent),
			"green": String(describing: color.greenComponent),
			"blue": String(describing: color.blueComponent),
			"alpha": String(describing: color.alphaComponent),
		]
	}
}

// MARK: - Helpers

private extension NSColor {
	var components: (CGFloat, CGFloat, CGFloat, CGFloat) {
		return ((redComponent * 255).rounded(), (greenComponent * 255).rounded(), (blueComponent * 255).rounded(), alphaComponent)
	}
}

extension ColorStyle {
	static func colorStyle(for color: NSColor, in colorStyles: [ColorStyle]) -> ColorStyle? {
		return colorStyles.first(where: { $0.color.components == color.components })
	}
}
