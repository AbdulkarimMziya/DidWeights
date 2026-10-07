//
//  PlanFilterChip.swift
//  DidWeights
//
//  A static "All Plans" pill above the plan list. There's no category/tag
//  field on WorkoutPreset to filter by, so this is intentionally just
//  chrome — no state, no binding — until there's something real to filter.
//

import SwiftUI

struct PlanFilterChip: View {
    var title: String = "All Plans"

    var body: some View {
        Text(title)
            .font(.appCaption.weight(.bold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, .oneAndAHalfX)
            .padding(.vertical, .halfX)
            .background(Color("Primary"), in: Capsule())
            .fixedSize()
    }
}

#Preview {
    PlanFilterChip()
        .padding()
        .background(Color(.neutral))
}
