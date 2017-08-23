//
//  CodeGenerator.swift
//  SketchStyleExporter
//
//  Created by Dylan Lewis on 12/08/2017.
//  Copyright © 2017 Dylan Lewis. All rights reserved.
//

import Foundation

/// A `String` of a code template, where replacable ranges are denoted as
/// `<replacableDeclaration>` and `</replacableDeclaration>`, and replaceable
/// elements are denoted as `<#=replaceableElement#>`
typealias Template = String

struct CodeGenerator {
	// MARK: - Stored properties
	
	private let template: Template
	private var templateCodeLines: [String]
	var fileExtension: String
	
	// MARK: - Initializer
	
	/// Creates a `CodeGenerator` with a given template and an array of groups
	/// of elements to replace. Each element of each group will have code
	/// generated for it, using the provided template.
	///
	/// - Warning: The template must have a file extension.
	///
	/// - Parameters:
	///   - template: The template of code to generate.
	/// - Throws: An error if the file extension cannot be found.
	init(template: Template) throws {
		self.template = template
		let templateLinesWithFileExtension = template.components(separatedBy: "\n")
		(fileExtension, templateCodeLines) = try templateLinesWithFileExtension.extractingFileExtension()
	}
	
	// MARK: - Code Generation
	
	/// Code generated by replacing the `codeTemplateReplacables` in the
	/// `template`.
	///
	/// - Parameter codeTemplateReplacables: An array of groups of elements to
	///										 replace. Each element of each group
	///										 will have code generated for it,
	///										 using the provided template.
	/// - Returns: The generated code of the template replacables and the
	///			   template.
	func generatedCode(for codeTemplateReplacables: [[CodeTemplateReplacable]]) -> String {
		let headerLines = """
		Automatically generated by SketchStyleExporter
		https://github.com/dylanslewis/SketchStyleExporter
		"""
		let generatedDocumentHeaderLines = headerLines.components(separatedBy: "\n").map(HeaderLine.init)
		let codeTemplateReplacables = [generatedDocumentHeaderLines] + codeTemplateReplacables

		// Iterate over each group of `codeTemplateReplacables` and
		var codeLines = templateCodeLines
		codeTemplateReplacables.forEach({ codeLines = codeLines.replacingCodePlaceholders(usingReplacementItems: $0) })
		codeLines.validateCodeLines()
		return codeLines.joined(separator: "\n")
	}
}

// MARK: - HeaderLine

private extension CodeGenerator {
	/// A line of text to be shown in the header of the generated file.
	struct HeaderLine: CodeTemplateReplacable {
		static let declarationName: String = "generatedFileHeader"
		let headerLine: String
		
		var replacementDictionary: [String: String] {
			return ["headerLine": headerLine]
		}
	}
}

// MARK: - Error

extension CodeGenerator {
	enum Error: Swift.Error {
		case noFileExtensionFound
	}
}

// MARK: - Helpers

private extension Array where Iterator.Element == String {
	// FIXME: Add docs
	func extractingFileExtension() throws -> (String, [String]) {
		let fileExtensionReference = "fileExtension".metadataPlaceholderReference
		var templateCodeLines = self
		guard let (index, element) = enumerated().first(where: { $0.element.contains(fileExtensionReference) }) else {
			throw CodeGenerator.Error.noFileExtensionFound
		}
		let fileExtension = element.replacingOccurrences(of: fileExtensionReference, with: "")
		templateCodeLines.remove(at: index)
		return (fileExtension, templateCodeLines)
	}
	
	/// Replaces all placeholders in each of the array's code lines, by looking
	/// up the corresponding value in the `replacementDictionary`.
	///
	/// - Parameter replacementDictionary: A dictionary where the keys are the
	///									   replacable element's placeholder and
	///									   the value is the replacement for that
	///									   placeholder.
	/// - Returns: The original array with replaced placeholders.
	
	// FIXME: Update docs
	func replacingCodePlaceholders(usingReplacementDictionary replacementDictionary: [String: String], isDeprecated: Bool) -> [String] {
		let deprecatedKey = "deprecated"
		let deprecatedReference = "\(deprecatedKey)=\(isDeprecated)".conditionalCodePlaceholderReference
				
		return map({ line -> String in
			var codeLineWithReplacedPlaceholders = line
			replacementDictionary.forEach({ (arg) in
				let (replacementKey, replacementValue) = arg
				codeLineWithReplacedPlaceholders = codeLineWithReplacedPlaceholders
					.replacingOccurrences(of: replacementKey.codePlaceholderReference, with: replacementValue)
			})
			return codeLineWithReplacedPlaceholders
		}).flatMap({ line -> String? in
			switch line.contains(deprecatedReference) {
			case true:
				// Condition is matched, remove the reference from the line.
				return line.replacingOccurrences(of: deprecatedReference, with: "")
			case false where line.contains(deprecatedKey):
				// It contains the key, but the condition is not matched. Remove
				// the line.
				return nil
			case false:
				return line
			}
		})
	}
	
	/// Replaces code placeholders in an array of code lines by finding the
	/// start declaration and end declaration, getting the replacement template
	/// and then replacing the placeholders in that template using each of the
	/// replacement items. The original code placeholders are then removed from
	/// the code lines.
	///
	/// - Parameters:
	///   - replacementItems: The items used to replace the code placeholders.
	///   - codeLines: The code lines that contain the code placeholders
	/// - Returns: The code lines with replaced code placeholders.
	func replacingCodePlaceholders(usingReplacementItems replacementItems: [CodeTemplateReplacable]) -> [String] {
		guard let firstReplacementItem = replacementItems.first else {
			print("⚠️ Unable to find element type.")
			return self
		}
		
		let replacementElementType = type(of: firstReplacementItem)
		let declarationName = replacementElementType.declarationName
		
		var codeLinesWithReplacement = self
		var containsDeclarationForType = true
		repeat {
			guard
				let declarationStartIndex = codeLinesWithReplacement.index(where: { $0.contains(declarationName.declarationStartReference) }),
				let declarationEndIndex = codeLinesWithReplacement.index(where: { $0.contains(declarationName.declarationEndReference) })
			else {
				containsDeclarationForType = false
				continue
			}
			
			// Extract the template for the given replacement item type.
			let replacementItemTemplate = Array(codeLinesWithReplacement[declarationStartIndex.advanced(by: 1)..<declarationEndIndex])
			let codeLinesWithReplacedPlaceholders = replacementItems
				.map({ return replacementItemTemplate
					.replacingCodePlaceholders(usingReplacementDictionary: $0.replacementDictionary, isDeprecated: $0.isDeprecated) })
				.flatMap({ $0 })
			codeLinesWithReplacement.replaceSubrange(declarationStartIndex...declarationEndIndex, with: codeLinesWithReplacedPlaceholders)
		} while containsDeclarationForType == true
		
		return codeLinesWithReplacement
	}
	
	/// Checks that there are no placeholders remaining in the code lines. If
	/// any are found, a warning is printed to the console.
	func validateCodeLines() {
		enumerated().forEach { arg in
			let (offset, element) = arg
			if element.contains("<#=") {
				print("⚠️ Unreplaced placeholder at line \(offset):\n" + element + "\n")
			}
		}
	}
}

private extension String {
	private enum ReplaceableReference {
		static let start: String = "<#"
		static let end: String = "#>"
	}
	
	private func replaceableReference(withSymbol symbol: String) -> String {
		return ReplaceableReference.start + symbol + self + ReplaceableReference.end
	}
	
	/// Wraps the current string in a code placeholder reference.
	var codePlaceholderReference: String {
		return replaceableReference(withSymbol: "=")
	}
	
	var conditionalCodePlaceholderReference: String {
		return replaceableReference(withSymbol: "?")
	}
	
	var metadataPlaceholderReference: String {
		return replaceableReference(withSymbol: "@")
	}
	
	/// Wraps the current string in a declaration start reference.
	var declarationStartReference: String {
		return "<" + self + ">"
	}
	
	/// Wraps the current string in a declaration end reference.
	var declarationEndReference: String {
		return "</" + self + ">"
	}
}
