//
//  ProfileCardView.swift
//  DidWeights
//
//  Built to match the Settings mockup's profile row, but there's no user/
//  account model anywhere in this app yet, so it's not wired into
//  SettingsView.body — it just compiles and previews on its own, one line
//  away from being added once there's real profile data to show.
//

import SwiftUI

struct ProfileCardView: View {
    var body: some View {
        HStack(spacing: .oneAndAHalfX) {
            ZStack {
                Circle().fill(Color.tileBG)
                Text("AJ")
                    .font(.appHeadline)
                    .foregroundStyle(Color.accentText)
            }
            .frame(width: .sevenX, height: .sevenX)

            VStack(alignment: .leading, spacing: .quarterX) {
                Text("Your Name")
                    .font(.appHeadline)
                    .foregroundStyle(Color.primaryHeadingTxt)
                Text("Free Plan")
                    .font(.appCaption)
                    .foregroundStyle(Color.secondaryTxt)
            }

            Spacer()

            Button {
                // No profile/account model exists yet — nothing to edit.
            } label: {
                Text("Edit")
                    .font(.appCaption.weight(.semibold))
                    .foregroundStyle(Color.accentText)
                    .padding(.horizontal, .oneAndAHalfX)
                    .padding(.vertical, .halfX)
                    .background(Color(.tertiary), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.twoX)
        .appCard()
    }
}

#Preview {
    ProfileCardView()
        .padding()
        .background(Color(.neutral))
}
