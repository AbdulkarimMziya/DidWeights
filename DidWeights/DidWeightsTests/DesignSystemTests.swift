//
//  DesignSystemTests.swift
//  DidWeightsTests
//

import SwiftUI
import Testing
@testable import DidWeights

@MainActor
@Suite struct DesignSystemTests {
    /// Guards the three things that must line up for the headline face to load:
    /// the file is in the bundle, `UIAppFonts` names it, and the PostScript name
    /// in `DesignSystem` matches the one baked into the file. Getting any of them
    /// wrong makes `Font.custom` fall back silently rather than fail.
    @Test func bundledDisplayFontIsRegistered() {
        #expect(UIFont(name: "InterDisplay-Bold", size: 34) != nil)
    }

    @Test func bundledDisplayFontResolvesToInterDisplay() throws {
        let font = try #require(UIFont(name: "InterDisplay-Bold", size: 34))
        #expect(font.familyName == "Inter Display")
        #expect(font.pointSize == 34)
    }

    /// Space Grotesk is no longer the display face but is still shipped and declared,
    /// so that it stays a one-line switch away. This fails if it quietly stops being bundled.
    @Test func spaceGroteskRemainsAvailable() throws {
        let font = try #require(UIFont(name: "SpaceGrotesk-Bold", size: 34))
        #expect(font.familyName == "Space Grotesk")
    }

    @Test func bundledEyebrowFontResolvesToBarlow() throws {
        let font = try #require(UIFont(name: "Barlow-SemiBold", size: 12))
        #expect(font.familyName == "Barlow")
        #expect(font.pointSize == 12)
    }

    @Test func bundledTitleFontResolvesToInter() throws {
        let font = try #require(UIFont(name: "Inter-Bold", size: 21))
        #expect(font.familyName == "Inter")
    }

    /// "Inter", not "Inter SemiBold", even though the file's legacy family record
    /// (name ID 1) says the latter — CoreText reports the typographic family (name ID 16)
    /// when a font has one. Reading the raw name table predicts the wrong answer here.
    @Test func bundledHeadlineFontResolvesToInter() throws {
        let font = try #require(UIFont(name: "Inter-SemiBold", size: 16))
        #expect(font.familyName == "Inter")
    }
}
