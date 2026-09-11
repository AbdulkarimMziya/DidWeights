//
//  ExerciseThumbnail.swift
//  DidWeights
//
//  Small accent-tinted square with a muscle-group-derived SF Symbol. Used on the
//  Home plan cards. Presentational only.
//

import SwiftUI

struct ExerciseThumbnail: View {
    var muscleGroup: String? = nil
    var size: CGFloat = 44

    private var symbol: String {
        switch muscleGroup?.lowercased() {
        case let g? where g.contains("leg") || g.contains("quad") || g.contains("glute"):
            return "figure.run"
        case let g? where g.contains("chest") || g.contains("push"):
            return "figure.strengthtraining.traditional"
        case let g? where g.contains("back") || g.contains("pull"):
            return "figure.rower"
        case let g? where g.contains("core") || g.contains("ab"):
            return "figure.core.training"
        case let g? where g.contains("cardio"):
            return "figure.indoor.cycle"
        default:
            return "dumbbell.fill"
        }
    }

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(Color.accentText)
            .frame(width: size, height: size)
            .background(Color.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
    }
}

#Preview {
    HStack {
        ExerciseThumbnail(muscleGroup: "Chest")
        ExerciseThumbnail(muscleGroup: "Legs")
        ExerciseThumbnail(muscleGroup: nil)
    }
    .padding()
    .background(Color.appBg)
}
