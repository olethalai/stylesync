//
//  StyleExporterTests.swift
//  StyleSyncTests
//
//  Created by Dylan Lewis on 12/11/2017.
//

import XCTest
@testable import StyleSyncCore
import Files

class StyleExporterTests: XCTestCase {
	// MARK: - Constants
	
	private enum Constant {
		static let fileWithReferencesToDeprecatedStylesName = "FileWithReferenceToDeprecatedStyles.fileExtension"
		static let fileWithReferencesToNewStylesName = "FileWithReferenceToNewStyles.fileExtension"
	}
	
	// MARK: - Stored variables
	
	private let projectFolder: Folder = .current
	private let textStylesTemplate: File = try! testResources.file(named: "TextStylesTemplate")
	private let colorStylesTemplate: File = try! testResources.file(named: "ColorStylesTemplate")
	
	private let deprecatedColorStyle = ColorStyle(
		name: "Deprecated Color Style",
		identifier: "C1",
		color: .red,
		isDeprecated: true
	)
	private let newColorStyle = ColorStyle(
		name: "New Color Style",
		identifier: "C2",
		color: .green,
		isDeprecated: false
	)
	
	// MARK: - Computed variables
	
	private var generatedRawTextStylesFile: File {
		return try! projectFolder.createFileIfNeeded(withName: "generatedRawTextStylesFile.json")
	}
	private var generatedRawColorStylesFile: File {
		return try! projectFolder.createFileIfNeeded(withName: "generatedRawColorStylesFile.json")
	}
	
	private var renamedNewColorStyle: ColorStyle {
		return ColorStyle(
			name: "Renamed New Color Style",
			identifier: newColorStyle.identifier,
			color: newColorStyle.color,
			isDeprecated: false
		)
	}
	
	private var deprecatedTextStyle: TextStyle {
		return TextStyle(
			name: "Deprecated Text Style",
			identifier: "T1",
			fontName: "FontName",
			pointSize: 16,
			kerning: 0,
			lineHeight: 20,
			colorStyle: deprecatedColorStyle,
			isDeprecated: true
		)
	}
	private var newTextStyle: TextStyle {
		return TextStyle(
			name: "New Text Style",
			identifier: "T2",
			fontName: "DifferentFontName",
			pointSize: 18,
			kerning: 2,
			lineHeight: 16,
			colorStyle: newColorStyle,
			isDeprecated: false
		)
	}
	private var renamedNewTextStyle: TextStyle {
		return TextStyle(
			name: "Renamed New Text Style",
			identifier: newTextStyle.identifier,
			fontName: newTextStyle.fontName,
			pointSize: newTextStyle.pointSize,
			kerning: newTextStyle.kerning,
			lineHeight: newTextStyle.lineHeight,
			colorStyle: newTextStyle.colorStyle,
			isDeprecated: false
		)
	}
	
	// MARK: - Overrides
	
	override func tearDown() {
		// Remove the raw style files.
		do {
			try generatedRawTextStylesFile.delete()
		} catch {
			print(error)
		}
		do {
			try generatedRawColorStylesFile.delete()
		} catch {
			print(error)
		}
		deleteFileWithReferencesToDeprecatedStyles()
		deleteFileWithReferencesToNewStyles()
		super.tearDown()
	}
	
	// MARK: - Tests
	
	func testWhenADeprecatedStyleIsUsedInTheProjectThenFileNamesForDeprecatedStyleNamesHasTheCorrectValues() {
		createFileWithReferencesToDeprecatedStyles()
		
		let styleExporter = getStylesExporterAndExportStyles(
			latestTextStyles: [newTextStyle],
			latestColorStyles: [newColorStyle],
			previouslyExportedTextStyles: [deprecatedTextStyle],
			previouslyExportedColorStyles: [deprecatedColorStyle]
		)
		
		let fileNamesForDeprecatedStyleNames = styleExporter.fileNamesForDeprecatedStyleNames
		XCTAssertEqual(fileNamesForDeprecatedStyleNames[deprecatedTextStyle.name]?.count, 1)
		XCTAssertEqual(fileNamesForDeprecatedStyleNames[deprecatedColorStyle.name]?.count, 1)
	}
	
	func testWhenADeprecatedStyleIsUsedInTheProjectThenNewStylesContainsDeprecatedStyles() {
		createFileWithReferencesToDeprecatedStyles()
		
		let styleExporter = getStylesExporterAndExportStyles(
			latestTextStyles: [newTextStyle],
			latestColorStyles: [newColorStyle],
			previouslyExportedTextStyles: [deprecatedTextStyle],
			previouslyExportedColorStyles: [deprecatedColorStyle]
		)
		
		let newDeprecatedTextStyles = styleExporter.newTextStyles.filter({ $0.isDeprecated })
		let newDeprecatedColorStyles = styleExporter.newColorStyles.filter({ $0.isDeprecated })
		
		XCTAssertEqual(newDeprecatedTextStyles.count, 1)
		XCTAssertEqual(newDeprecatedColorStyles.count, 1)
	}
	
	func testWhenOldStylesAreUsedInTheProjectThenNewStylesContainsThoseStylesAsDeprecatedStyles() {
		createFileWithReferencesToNewStyles()
		
		let styleExporter = getStylesExporterAndExportStyles(
			latestTextStyles: [],
			latestColorStyles: [],
			previouslyExportedTextStyles: [newTextStyle],
			previouslyExportedColorStyles: [newColorStyle]
		)
		
		let newDeprecatedTextStyles = styleExporter.newTextStyles.filter({ $0.isDeprecated })
		let newDeprecatedColorStyles = styleExporter.newColorStyles.filter({ $0.isDeprecated })
		
		XCTAssertEqual(newDeprecatedTextStyles.count, 1)
		XCTAssertEqual(newDeprecatedColorStyles.count, 1)
	}
	
	func testWhenADeprecatedStyleIsNotUsedInTheProjectThenNewStylesDoesNotContainDeprecatedStyles() {
		let styleExporter = getStylesExporterAndExportStyles(
			latestTextStyles: [newTextStyle],
			latestColorStyles: [newColorStyle],
			previouslyExportedTextStyles: [deprecatedTextStyle],
			previouslyExportedColorStyles: [deprecatedColorStyle]
		)
		
		let newDeprecatedTextStyles = styleExporter.newTextStyles.filter({ $0.isDeprecated })
		let newDeprecatedColorStyles = styleExporter.newColorStyles.filter({ $0.isDeprecated })
		
		XCTAssertEqual(newDeprecatedTextStyles.count, 0)
		XCTAssertEqual(newDeprecatedColorStyles.count, 0)
	}
	
	func testWhenAStyleIsRenamedThenTheReferencesAreUpdated() {
		createFileWithReferencesToNewStyles()
		
		let _ = getStylesExporterAndExportStyles(
			latestTextStyles: [renamedNewTextStyle],
			latestColorStyles: [renamedNewColorStyle],
			previouslyExportedTextStyles: [newTextStyle],
			previouslyExportedColorStyles: [newColorStyle]
		)
		
		let fileWithReferencesToNewStylesString: String
		do {
			let fileWithReferencesToNewStyles = try projectFolder.file(
				named: Constant.fileWithReferencesToNewStylesName
			)
			fileWithReferencesToNewStylesString = try fileWithReferencesToNewStyles.readAsString()
		} catch {
			return XCTFail(error.localizedDescription)
		}
		
		let expectedFileWithReferencesToNewStylesString = """
			\(renamedNewTextStyle.name.camelcased)
			\(renamedNewColorStyle.name.camelcased)
			"""
		XCTAssertEqual(fileWithReferencesToNewStylesString, expectedFileWithReferencesToNewStylesString)
	}
	
	func testNewStylesContainsAllTheLatestStyles() {
		let styleExporter = getStylesExporterAndExportStyles(
			latestTextStyles: [newTextStyle],
			latestColorStyles: [newColorStyle],
			previouslyExportedTextStyles: [],
			previouslyExportedColorStyles: []
		)
		
		XCTAssertEqual(styleExporter.newTextStyles.count, 1)
		XCTAssertEqual(styleExporter.newColorStyles.count, 1)
	}
	
	// MARK: - Helpers
	
	private func getStylesExporterAndExportStyles(
		latestTextStyles: [TextStyle],
		latestColorStyles: [ColorStyle],
		previouslyExportedTextStyles: [TextStyle],
		previouslyExportedColorStyles: [ColorStyle]
	) -> StyleExporter {
		let styleExporter = StyleExporter(
			latestTextStyles: latestTextStyles,
			latestColorStyles: latestColorStyles,
			previouslyExportedTextStyles: previouslyExportedTextStyles,
			previouslyExportedColorStyles: previouslyExportedColorStyles,
			projectFolder: projectFolder,
			textStyleTemplateFile: textStylesTemplate,
			colorStyleTemplateFile: colorStylesTemplate,
			exportTextFolder: projectFolder,
			exportColorsFolder: projectFolder,
			generatedRawTextStylesFile: generatedRawTextStylesFile,
			generatedRawColorStylesFile: generatedRawColorStylesFile,
			previousStylesVersion: .firstVersion
		)
		do {
			try styleExporter.exportStyles()
		} catch {
			XCTFailAndAbort(error.localizedDescription)
		}
		return styleExporter
	}
	
	private func createFileWithReferencesToDeprecatedStyles() {
		let stringWithReferenceToDeprecatedStyles = """
			\(deprecatedTextStyle.name.camelcased)
			\(deprecatedColorStyle.name.camelcased)
			"""
		do {
			try projectFolder.createFile(
				named: Constant.fileWithReferencesToDeprecatedStylesName,
				contents: stringWithReferenceToDeprecatedStyles
			)
		} catch {
			XCTFailAndAbort(error.localizedDescription)
		}
	}
	
	private func createFileWithReferencesToNewStyles() {
		let stringWithReferenceToNewStyles = """
		\(newTextStyle.name.camelcased)
		\(newColorStyle.name.camelcased)
		"""
		do {
			try projectFolder.createFile(
				named: Constant.fileWithReferencesToNewStylesName,
				contents: stringWithReferenceToNewStyles
			)
		} catch {
			XCTFailAndAbort(error.localizedDescription)
		}
	}
	
	private func deleteFileWithReferencesToDeprecatedStyles() {
		do {
			try
				projectFolder
				.file(named: Constant.fileWithReferencesToDeprecatedStylesName)
				.delete()
		} catch {
			print(error.localizedDescription)
		}
	}
	
	private func deleteFileWithReferencesToNewStyles() {
		do {
			try
				projectFolder
					.file(named: Constant.fileWithReferencesToNewStylesName)
					.delete()
		} catch {
			print(error.localizedDescription)
		}
	}
}
