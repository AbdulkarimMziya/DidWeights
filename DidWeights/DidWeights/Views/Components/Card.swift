//
//  Card.swift
//  DidWeights
//
//  The app's standard card container: a surface with the shared corner radius
//  and border treatment, wrapping arbitrary content. Height is content driven —
//  the card is as tall as what's inside it. Presentation only.
//

import SwiftUI

enum CardStyle {
    /// Standard surface: fill, hairline border, soft shadow.
    case solid(fill: Color)
    /// Tinted fill behind a dashed accent border — "add something" affordances.
    case dashed
}

struct Card<Content: View>: View {
    var style: CardStyle = .solid(fill: .cardBg)
    var padding: CGFloat = .twoX
    var alignment: Alignment = .leading
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: alignment)
            .modifier(CardSurface(style: style))
    }
}

// MARK: - Surface

private struct CardSurface: ViewModifier {
    let style: CardStyle

    func body(content: Content) -> some View {
        switch style {
        case let .solid(fill):
            content.appCard(fill: fill)
        case .dashed:
            content
                .background(
                    Color(.tertiary).opacity(0.35),
                    in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .strokeBorder(
                            Color.accentText.opacity(0.45),
                            style: StrokeStyle(lineWidth: 1.5, dash: [6])
                        )
                )
        }
    }
}

#Preview("Styles") {
    VStack(spacing: .twoX) {
        Card {
            Text("Solid — default fill")
                .font(.appHeadline)
                .foregroundStyle(Color.primaryHeadingTxt)
        }

        Card(style: .solid(fill: Color(.neutral))) {
            VStack(alignment: .leading, spacing: .halfX) {
                Text("Solid — neutral fill")
                    .font(.appHeadline)
                    .foregroundStyle(Color.primaryHeadingTxt)
                Text("Sizes to its content")
                    .font(.appCaption)
                    .foregroundStyle(Color.secondaryTxt)
            }
        }

        Card(style: .dashed, alignment: .center) {
            Text("Dashed")
                .font(.appHeadline)
                .foregroundStyle(Color.accentText)
        }

        Card(padding: .fourX) {
            Text("Custom padding")
                .font(.appHeadline)
                .foregroundStyle(Color.primaryHeadingTxt)
        }
    }
    .padding()
    .frame(maxHeight: .infinity, alignment: .top)
    .background(Color(.neutral))
}
