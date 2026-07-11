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
        HomeView()
            .environment(manager)
    }
}

#Preview {
    ContentView()
}
