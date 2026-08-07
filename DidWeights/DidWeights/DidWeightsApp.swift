//
//  DidWeightsApp.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-06-06.
//

import SwiftData
import SwiftUI


@main
struct DidWeightsApp: App {
    var body: some Scene {
        WindowGroup {
            SplashScreenView()
        }
        .modelContainer(for: [Exercise.self, SavedWorkout.self, Workout.self])
    }
}
