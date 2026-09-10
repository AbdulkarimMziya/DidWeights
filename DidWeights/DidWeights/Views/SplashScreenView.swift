//
//  SplashScreenView.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-08-01.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var isActive = false

    // Splash is committed to the dark identity regardless of the device theme,
    // so these are literal rather than asset tokens.
    private let ground = Color(red: 0.04, green: 0.043, blue: 0.04)
    private let lime = Color(red: 0.80, green: 0.97, blue: 0.29)

    var body: some View {
        if isActive {
            ContentView()
        } else {
            VStack(spacing: Spacing.lg) {
                Image("AppIconSplash")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                Text("Did Weights")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(lime)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ground)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        isActive = true
                    }
                }
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
