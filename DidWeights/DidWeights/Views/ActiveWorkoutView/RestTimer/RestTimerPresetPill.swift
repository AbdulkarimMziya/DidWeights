//
//  RestTimerPresetPill.swift
//  DidWeights
//

import SwiftUI

struct RestTimerPresetPill: View {
    let preset: RestTimerPreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(preset.label)
                .font(.appCaption.weight(.semibold))
                .foregroundStyle(isSelected ? Color.primaryBtnTxt : Color.accentText)
                .padding(.horizontal, .oneAndAHalfX)
                .padding(.vertical, .halfX + .quarterX)
                .frame(maxWidth: .infinity)
                // accentText flips dark green (light mode) / light mint (dark
                // mode), so the selected fill inverts with the theme instead
                // of staying a fixed green that goes low-contrast in dark mode.
                .background(isSelected ? Color.accentText : Color(.tertiary), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HStack {
        RestTimerPresetPill(preset: .thirtySeconds, isSelected: false) {}
        RestTimerPresetPill(preset: .ninetySeconds, isSelected: true) {}
    }
    .padding()
}
