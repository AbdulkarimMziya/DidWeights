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
        .modelContainer(for: [LegacyExercise.self, LegacySavedWorkout.self, LegacyWorkout.self])
    }
}

/**
 Make a rootView
 import swiftdata
 check if workout exists using @Query
 if yes, pass workout to homeview via id or Workout or a flag isWorkingOut: bool
 */
