//
//  CGFloat+Spacing.swift
//  DidWeights
//
//  The app's spacing scale. Every value is a multiple of an 8pt base unit ("X"),
//  named so the multiple is readable at the call site: `.oneAndAHalfX` is 1.5 × 8.
//  Use these for stack spacing and padding — corner radii live in `Radius`.
//

import CoreGraphics

extension CGFloat {
    static let quarterX: CGFloat = 2
    static let halfX: CGFloat = 4
    static let oneX: CGFloat = 8
    static let oneAndAHalfX: CGFloat = 12
    static let twoX: CGFloat = 16
    static let twoAndAHalfX: CGFloat = 20
    static let threeX: CGFloat = 24
    static let fourX: CGFloat = 32
    static let fiveX: CGFloat = 40
    static let sixX: CGFloat = 48
    static let sevenX: CGFloat = 56
    static let eightX: CGFloat = 64
    static let nineX: CGFloat = 72
    static let tenX: CGFloat = 80
}
