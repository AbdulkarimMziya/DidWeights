//
//  DesignSystem.swift
//  DidWeights
//
//  Shared visual language: type scale, spacing/radius rhythm, the set-table
//  column grid, and the reusable button / card treatments. Presentation only —
//  nothing here touches the model or repository layer.
//

import SwiftUI

// MARK: - Type scale

extension Font {
    /// Large screen title (SF Pro Rounded).
    static let appDisplay = Font.system(size: 34, weight: .bold, design: .rounded)
    /// Section heading.
    static let appTitle = Font.system(size: 22, weight: .bold, design: .rounded)
    /// Card / row title.
    static let appHeadline = Font.system(size: 17, weight: .semibold)
    /// Body copy.
    static let appBody = Font.system(size: 15, weight: .regular)
    /// Subtitles, captions.
    static let appCaption = Font.system(size: 13, weight: .regular)
    /// Micro labels (stat-tile units, timestamps).
    static let appMicro = Font.system(size: 11, weight: .medium)
    /// The elapsed-time readout on the active workout header.
    static let appTimer = Font.system(size: 46, weight: .bold, design: .rounded).monospacedDigit()
}

// MARK: - Rhythm

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum Radius {
    static let card: CGFloat = 20
    static let button: CGFloat = 16
    static let tile: CGFloat = 16
    static let hero: CGFloat = 28
}

/// Fixed column widths for the active-workout set table. `SetHeaderView` and
/// `ExerciseSetRowView` both read these so the header sits exactly above its
/// columns and every row lines up. "Previous" takes the remaining flexible space.
enum SetColumn {
    static let index: CGFloat = 34
    static let weight: CGFloat = 64
    static let reps: CGFloat = 52
    static let check: CGFloat = 34
}

// MARK: - Elevation

extension View {
    func appShadow() -> some View {
        shadow(color: .black.opacity(0.25), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Card container

private struct AppCard: ViewModifier {
    var cornerRadius: CGFloat = Radius.card

    func body(content: Content) -> some View {
        content
            .background(Color.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.hairline, lineWidth: 1)
            )
            .appShadow()
    }
}

extension View {
    /// Standard surface: card background, continuous corners, hairline border, soft shadow.
    func appCard(cornerRadius: CGFloat = Radius.card) -> some View {
        modifier(AppCard(cornerRadius: cornerRadius))
    }
}

// MARK: - Action labels
//
// Applied to a button's *label* rather than as a `ButtonStyle`, so the enclosing
// button can keep `.buttonStyle(.borderless)` — required for buttons living
// inside a `List` row to be hit-tested independently.

extension View {
    /// Filled accent action. Dark: lime fill / near-black text. Light: dark-green
    /// fill / white text. Resolves from the `PrimaryBtn*` colorsets.
    func primaryActionLabel(compact: Bool = false) -> some View {
        self
            .font(.system(size: compact ? 15 : 17, weight: .bold))
            .foregroundStyle(Color.primaryBtnTxt)
            .frame(maxWidth: .infinity, minHeight: compact ? 40 : 52)
            .background(Color.primaryBtn)
            .clipShape(RoundedRectangle(cornerRadius: compact ? 12 : Radius.button, style: .continuous))
    }

    /// Tinted destructive action (Cancel Workout, Delete Set).
    func destructiveActionLabel(compact: Bool = false) -> some View {
        self
            .font(.system(size: compact ? 15 : 17, weight: .bold))
            .foregroundStyle(Color.deleteBtnTxt)
            .frame(maxWidth: .infinity, minHeight: compact ? 40 : 52)
            .background(Color.deleteBtnBg)
            .clipShape(RoundedRectangle(cornerRadius: compact ? 12 : Radius.button, style: .continuous))
    }
}
