//
//  WorkoutDetailView.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-07-30.
//

import SwiftData
import SwiftUI

struct HistoryDetailView: View {
    private let workoutID: UUID
    @Query private var matches: [Workout]

    init(workoutID: UUID) {
        self.workoutID = workoutID
        _matches = Query(filter: #Predicate<Workout> { $0.id == workoutID })
    }

    var body: some View {
        if let workout = matches.first {
            HistoryDetailContent(workout: workout)
        } else {
            ContentUnavailableView(
                "Workout Not Found",
                systemImage: "clock.arrow.circlepath"
            )
        }
    }
}

private struct HistoryDetailContent: View {
    let workout: Workout

    var body: some View {
        List {
            Section {
                HStack(spacing: Spacing.md) {
                    StatTile(systemImage: "clock", value: durationText, label: "Duration")
                    StatTile(systemImage: "list.bullet", value: "\(workout.exerciseGroups.count)", label: "Exercises")
                    StatTile(systemImage: "checkmark.circle", value: "\(workout.sets.count)", label: "Sets")
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            ForEach(workout.exerciseGroups) { group in
                Section {
                    ForEach(Array(group.sets.enumerated()), id: \.element.id) { index, set in
                        HStack {
                            Text("Set \(index + 1)")
                                .font(.appCaption)
                                .foregroundStyle(Color.secondaryTxt)
                            Spacer()
                            Text(setSummary(set))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.primaryHeadingTxt)
                        }
                        .listRowBackground(Color.cardBg)
                        .listRowSeparatorTint(Color.hairline)
                    }
                } header: {
                    Text(group.exercise.name)
                        .font(.appHeadline)
                        .foregroundStyle(Color.primaryHeadingTxt)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.appBg)
        .navigationTitle(workout.name)
    }

    private func setSummary(_ set: ExerciseSet) -> String {
        var parts: [String] = []
        if let reps = set.reps { parts.append("\(reps) reps") }
        if let weight = set.weight { parts.append("\(weight.formatted(.number.precision(.fractionLength(0...1)))) lb") }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }

    // "1h 12min" / "1h" / "12min" from the finished workout's elapsed time.
    // Workout.elapsed() already subtracts accumulatedPause; for a completed
    // workout the `asOf:` default is irrelevant.
    private var durationText: String {
        let totalMinutes = max(0, Int(workout.elapsed()) / 60)
        let h = totalMinutes / 60
        let m = totalMinutes % 60

        switch (h, m) {
        case (0, _): return "\(m) min"
        case (_, 0): return "\(h)h"
        default:     return "\(h)h \(m)min"
        }
    }
}

#Preview {
    // 1. Build an unseeded, in-memory model container
    let container = try! ModelContainer.inMemory(seeded: false)
    let context = container.mainContext

    // 2. Create Exercise objects and insert them into the context
    let benchPress = Exercise(name: "Bench Press", muscleGroup: "Chest")
    let bicepCurl = Exercise(name: "Bicep Curl", muscleGroup: "Arms")
    context.insert(benchPress)
    context.insert(bicepCurl)

    // 3. Create a Workout with an endDate (so it registers as completed) and insert it
    let workout = Workout(name: "Upper Body Power" )
    workout.endDate = Date().addingTimeInterval(4320) // 1h 12min workout duration
    context.insert(workout)

    // 4. Create ExerciseSets pointing at the workout/exercises with realistic values and insert them
    let set1 = ExerciseSet(order: 0, workout: workout, exercise: benchPress)
    set1.reps = 8
    set1.weight = 135.0
    set1.isCompleted = true

    let set2 = ExerciseSet(order: 1, workout: workout, exercise: benchPress)
    set2.reps = 6
    set2.weight = 145.0
    set2.isCompleted = true

    let set3 = ExerciseSet(order: 2, workout: workout, exercise: bicepCurl)
    set3.reps = 12
    set3.weight = 30.0
    set3.isCompleted = true

    context.insert(set1)
    context.insert(set2)
    context.insert(set3)

    // 5. Return the view target wrapped with a NavigationStack and the active model container modifier
    return NavigationStack {
        HistoryDetailView(workoutID: workout.id)
    }
    .modelContainer(container)
}
