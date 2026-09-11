//
//  ContentView.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-06-06.
//

import SwiftUI

struct ContentView: View {

    init() {
        // System material background (theme-aware); selected tint comes from
        // `.tint` below, unselected items follow the secondary text token.
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

        let normal = UIColor(Color.secondaryTxt)
        appearance.stackedLayoutAppearance.normal.iconColor = normal
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: normal]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house.fill") {
                HomeView()
            }

            Tab("History", systemImage: "clock.arrow.circlepath") {
                HistoryView()
            }

        }
        .tint(Color.accentText)
    }
}

#Preview {
    ContentView()
}
