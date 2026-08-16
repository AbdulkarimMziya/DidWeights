//
//  ContentView.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-06-06.
//

import SwiftUI

struct ContentView: View {
    @State private var manager = WorkoutManager()
    
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house.fill") {
                HomeView()
                    .environment(manager)
            }
            
            Tab("History", systemImage: "clock.arrow.circlepath") {
                HistoryView()
            }
                
        }
        .tint(Color("PrimaryBtnBG"))
    }
}

#Preview {
    ContentView()
}
