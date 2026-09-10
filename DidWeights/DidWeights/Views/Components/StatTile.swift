//
//  StatTile.swift
//  DidWeights
//
//  Icon · value · label block on a tile surface. Used on the active-workout
//  header and the history-detail summary. Purely presentational.
//

import SwiftUI

struct StatTile: View {
    let systemImage: String
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.accentText)

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primaryHeadingTxt)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.appMicro)
                .foregroundStyle(Color.secondaryTxt)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.tileBG)
        .clipShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
    }
}

#Preview {
    HStack(spacing: Spacing.md) {
        StatTile(systemImage: "clock", value: "52 min", label: "Duration")
        StatTile(systemImage: "list.bullet", value: "5", label: "Exercises")
        StatTile(systemImage: "repeat", value: "84", label: "Reps")
    }
    .padding()
    .background(Color.appBg)
}
