//
//  AddPlanCard.swift
//  DidWeights
//
//  The empty-state card, shown only when there are no saved plans — once
//  a real plan exists, adding another happens exclusively through the
//  section header's "+" button, not a trailing grid cell.
//
//  Same green family in both appearances, but not the same literal color:
//  background and text use tokens that already carry a muted dark-mode
//  variant (Tertiary, AccentText) instead of forcing .light and replaying
//  the bright light-mode value verbatim on a dark background. Only the
//  small icon badge stays a fixed white square in both modes — the same
//  "always-light accent on a colored surface" trick the Quick Start card's
//  arrow button uses, scoped to just that one element.
//

import SwiftUI

struct AddPlanCard: View {
    var body: some View {
        VStack(spacing: .oneX) {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color("Primary"))
                .padding(.oneX)
                .background(Color.white, in: RoundedRectangle(cornerRadius: .oneAndAHalfX, style: .continuous))
                .environment(\.colorScheme, .light)

            Text("Tap to Add a Plan")
                .font(.appHeadline)
                .foregroundStyle(Color.accentText)

            Text("Create a custom split")
                .font(.appCaption)
                .foregroundStyle(Color.secondaryTxt)
        }
        .multilineTextAlignment(.center)
        .padding(.threeX)
        .frame(maxWidth: .infinity)
        .background(Color(.tertiary), in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(
                    Color.accentText,
                    style: StrokeStyle(lineWidth: 1.5, dash: [6])
                )
        )
        .contentShape(Rectangle())
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Add a plan")
    }
}

#Preview {
    AddPlanCard()
        .padding()
        .background(Color(.neutral))
}
