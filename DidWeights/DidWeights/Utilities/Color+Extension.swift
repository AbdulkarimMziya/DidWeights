//
//  Color+Extension.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-08-14.
//

import Foundation
import SwiftUI

extension Color {
    static let cardBg = Color("CardRowBG")
    static let primaryBtnTxt = Color("PrimaryBtnText")
    static let checkmarkIcon = Color("CheckMarkIcon")
    static let primaryHeadingTxt = Color("PrimaryHeadingText")
    static let secondaryTxt = Color("SecondaryText")

    // The palette colors are read straight from Assets.xcassets:
    // `Color(.neutral)` and `Color(.tertiary)` use the generated symbols.
    // "Primary" and "Secondary" clash with SwiftUI's own `Color.primary` /
    // `Color.secondary`, so Xcode generates no symbol for them: use
    // `Color("Primary")` and `Color("Secondary")`. The redesign tokens
    // `tileBG`, `accentText`, `hairline`, `planCardBorder` and `card` also
    // come from generated symbols.
}
