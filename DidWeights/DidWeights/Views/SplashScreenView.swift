//
//  SplashScreenView.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-08-01.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var isActive = false

    var body: some View {
        if isActive {
            ContentView()
                .transition(.opacity)
        } else {
            Image("AppIconSplash")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 140)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .foregroundStyle(Color("Primary"))
                .background(Color(.neutral))
                .transition(.opacity)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation(.easeInOut(duration: 0.6)) {
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
