//
//  HomeView.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-06-19.
//

import SwiftData
import SwiftUI

@Observable
class HomeViewModel {
    
}

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Workout> { $0.endDate == nil })
    private var activeWorkouts: [Workout]

    // Retargeted onto the new schema — no more LegacySavedWorkout.
    @Query(sort: \WorkoutPreset.name) private var savedPlans: [WorkoutPreset]

    @State private var presentWorkout = false
    @State private var didAutoPresentWorkout = false
    @State private var presentCreatePlan = false
    @State private var planPendingEdit: WorkoutPreset?
    @State private var planPendingDelete: WorkoutPreset?
    @State private var errorMessage: String?

    private var workouts: WorkoutRepository { WorkoutRepository(context: modelContext) }
    private var presets: PresetRepository { PresetRepository(context: modelContext) }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(spacing: .threeX) {
                    PageHeader(isWorkoutActive: !activeWorkouts.isEmpty)
                    WeeklyConsistencySection()
                    QuickStartSection(workout: activeWorkouts.first, onStart: handleStartTapped)
                    workoutPlansSection
                }
                .padding()
            }
            .background(Color(.neutral).ignoresSafeArea())
            .scrollBounceBehavior(.always)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                // Drop the user straight back into a session left in progress,
                // but only the first time Home appears this launch — tab
                // switches and manual dismissals fall back to "Resume Workout".
                if !didAutoPresentWorkout && !activeWorkouts.isEmpty {
                    didAutoPresentWorkout = true
                    presentWorkout = true
                }
            }
            .sheet(isPresented: $presentWorkout) {
                ActiveWorkoutView()
            }
            .sheet(item: $planPendingEdit) { plan in
                CreatePlanView(editingPlan: plan)
            }
            .sheet(isPresented: $presentCreatePlan) {
                CreatePlanView()
            }
            .alert("Something went wrong", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Sections

    private var workoutPlansSection: some View {
        VStack(alignment: .leading, spacing: .oneAndAHalfX) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: .halfX) {
                    Text("Workout Plans")
                        .font(.appTitle)
                        .foregroundStyle(Color.primaryHeadingTxt)
                    Text("Select routine or build a custom split")
                        .font(.appCaption)
                        .foregroundStyle(Color.metaText)
                }

                Spacer()

                Button {
                    presentCreatePlan = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.primaryBtnTxt)
                        .padding(.oneX)
                        .background(Color("Primary"), in: .circle)
                        .environment(\.colorScheme, .light)
                }
            }

            PlanFilterChip()

            VStack(spacing: .twoX) {
                if savedPlans.isEmpty {
                    // The sole empty-state affordance — once a plan exists,
                    // adding another happens only through the "+" above.
                    AddPlanCard()
                        .onTapGesture { presentCreatePlan = true }
                } else {
                    ForEach(savedPlans) { plan in
                        WorkoutTemplateCard(
                            plan: plan,
                            onStart: { handleStartFromPlanTapped(plan) },
                            onEdit: { planPendingEdit = plan },
                            onDelete: { planPendingDelete = plan }
                        )
                    }
                }
            }
            .alert(
                "Delete \(planPendingDelete?.name ?? "Plan")?",
                isPresented: Binding(
                    get: { planPendingDelete != nil },
                    set: { if !$0 { planPendingDelete = nil } }
                )
            ) {
                Button("Delete", role: .destructive) {
                    if let plan = planPendingDelete {
                        do {
                            try presets.delete(plan)
                        } catch {
                            errorMessage = "Couldn't delete this plan: \(error.localizedDescription)"
                        }
                    }
                    planPendingDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    planPendingDelete = nil
                }
            } message: {
                Text("This can't be undone.")
            }
        }
    }

    private func handleStartTapped() {
        if activeWorkouts.isEmpty {
            do {
                try workouts.startEmptyWorkout()
            } catch {
                errorMessage = "Couldn't start a workout: \(error.localizedDescription)"
                return
            }
        }
        presentWorkout = true
    }

    private func handleStartFromPlanTapped(_ plan: WorkoutPreset) {
        guard activeWorkouts.isEmpty else {
            // A workout is already active — resume it rather than trying
            // to start a second one, same rule as the quick-start button.
            presentWorkout = true
            return
        }

        do {
            try workouts.startWorkout(from: plan)
            presentWorkout = true
        } catch {
            errorMessage = "Couldn't start this plan: \(error.localizedDescription)"
        }
    }
}

// MARK: - QuickStartSection

private struct QuickStartSection: View {
    let workout: Workout?
    var onStart: () -> Void

    private var isActive: Bool { workout != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: .oneAndAHalfX) {
            Text("Quick Start")
                .font(.appTitle)
                .foregroundStyle(Color.primaryHeadingTxt)

            Button(action: onStart) {
                VStack(alignment: .leading, spacing: .oneAndAHalfX) {
                    HStack {
                        Pill {
                            if let _ = workout {
                                HStack(spacing: .halfX) {
                                    Circle()
                                        .frame(width: .oneX)
                                        .foregroundColor(Color("Secondary"))
                                    Text("In progress")
                                }
                            } else {
                                Text("⚡️ Ready to go")
                            }
                        }
                        Spacer(minLength: 0)
                        if let workout {
                            QuickStartTimerPill(workout: workout)
                        }
                    }
                    HStack(spacing: .fourX) {
                        VStack(alignment: .leading, spacing: .halfX) {
                            Text(isActive ? "Resume Workout" : "Start a Workout")
                                .font(.appTitle.weight(.heavy))
                            Text(isActive ? "Workout in progress" : "Blank session • Log sets & exercises as you go")
                                .font(.appCaption)
                                .opacity(0.75)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Image(systemName: "arrow.right")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(Color("Primary"))
                            .frame(width: .sevenX, height: .sevenX)
                            .background(Color(.neutral), in: .circle)
                            .environment(\.colorScheme, .light)
                    }

                    if let workout {
                        Spacer()
                        Divider()
                            .background(Color.white)
                        VStack(alignment: .leading) {
                            Text("Progress: \(workout.completedSetCount) of \(workout.totalSetCount) Sets")
                                .font(.appCaption.bold())
                            ProgressBar(fraction: workout.setProgress)
                        }
                    }
                }
                .padding(.twoAndAHalfX)
                .background(Color("Primary"))
                .clipShape(RoundedRectangle(cornerRadius: .twoX, style: .continuous))
                .environment(\.colorScheme, .dark)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom)
    }
}

// MARK: - Pill

private struct Pill<Content: View>: View {
    @ViewBuilder
    let content: () -> Content
    
    var body: some View {
        content()
            .padding(.horizontal, .oneAndAHalfX)
            .padding(.vertical, .halfX)
            .background(Color.white.opacity(0.18), in: Capsule())
            .opacity(0.7)
            .font(.appCaption.weight(.semibold))
    }
}

// MARK: - QuickStartTimerPill

private struct QuickStartTimerPill: View {
    let workout: Workout

    var body: some View {
        Pill {
            HStack(spacing: .halfX) {
                if workout.isPaused {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 11, weight: .bold))
                        .accessibilityLabel("Paused")
                }
            
                WorkoutTimerView(workout: workout)
            }
        }
    }
}

// MARK: - ProgressBar

private struct ProgressBar: View {
    
    let fraction: Double
    var height: CGFloat = 8

    private var clampedFraction: Double {
        min(max(fraction, 0), 1)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.black.opacity(0.25))

            // A ZStack child can't ask how wide its container is, so the fill
            // needs the proxy to size itself proportionally. scaleEffect would
            // distort the capsule's end caps instead.
            GeometryReader { proxy in
                Capsule()
                    .fill(Color.white)
                    .frame(width: proxy.size.width * clampedFraction)
            }
        }
        .frame(height: height)
        // The adjacent label already states the same progress; announcing the
        // bar too would read it twice.
        .accessibilityHidden(true)
    }
}

// MARK: - PageHeader

private struct PageHeader: View {
    let isWorkoutActive: Bool

    private static let initials = "AJ"

    private var eyebrow: String {
        isWorkoutActive ? "CURRENT SESSION ACTIVE" : "WELCOME BACK"
    }

    private var headline: String {
        isWorkoutActive ? "Workout in Progress" : "Ready to Train?"
    }

    var body: some View {
        HStack(alignment: .center, spacing: .twoX) {
            VStack(alignment: .leading, spacing: .halfX) {
                Text(eyebrow)
                    .font(.appEyebrow)
                    .tracking(0.8)
                    .foregroundStyle(.metaText)

                Text(headline)
                    .font(.appDisplay)
                    .foregroundStyle(Color.primaryHeadingTxt)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

//            Text(Self.initials)
//                .font(.appHeadline)
//                .foregroundStyle(Color.primaryHeadingTxt)
//                .frame(width: 44, height: 44)
//                .background(Color.card, in: .circle)
//                .overlay(Circle().strokeBorder(Color("Primary"), lineWidth: 2))
//                .accessibilityHidden(true)
        }
    }
}



#Preview {
    let container = try! ModelContainer.inMemory(seeded: false)
    return HomeView()
        .modelContainer(container)
}

#Preview("Quick Start — idle") {
    let container = try! ModelContainer.inMemory(seeded: false)

    return QuickStartSection(workout: nil, onStart: {})
        .padding()
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(.neutral))
        .modelContainer(container)
}

#Preview("Quick Start — running") {
    let container = try! ModelContainer.inMemory(seeded: false)
    let workouts = WorkoutRepository(context: container.mainContext)
    let workout = try! workouts.startEmptyWorkout(
        named: "Push Day",
        at: Date().addingTimeInterval(-1_725)
    )

    return QuickStartSection(workout: workout, onStart: {})
        .padding()
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(.neutral))
        .modelContainer(container)
}

#Preview("Quick Start — paused") {
    let container = try! ModelContainer.inMemory(seeded: false)
    let workouts = WorkoutRepository(context: container.mainContext)
    let workout = try! workouts.startEmptyWorkout(
        named: "Leg Day",
        at: Date().addingTimeInterval(-4_400)
    )
    try! workouts.pause(workout, at: Date().addingTimeInterval(-600))

    return QuickStartSection(workout: workout, onStart: {})
        .padding()
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(.neutral))
        .modelContainer(container)
}

#Preview("Page header states") {
    VStack(spacing: .threeX) {
        PageHeader(isWorkoutActive: false)
        PageHeader(isWorkoutActive: true)
    }
    .padding()
    .frame(maxHeight: .infinity, alignment: .top)
    .background(Color(.neutral))
}
