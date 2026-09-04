//
//  ContentView.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-06-06.
//

import SwiftUI

struct ContentView: View {
    
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house.fill") {
                HomeView()
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
