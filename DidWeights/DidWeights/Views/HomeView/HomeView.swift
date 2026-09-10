//
//  HomeView.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-06-19.
//

import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Workout> { $0.endDate == nil })
    private var activeWorkouts: [Workout]

    // Retargeted onto the new schema — no more LegacySavedWorkout.
    @Query(sort: \WorkoutPreset.name) private var savedPlans: [WorkoutPreset]

    @State private var presentWorkout = false
    @State private var didAutoPresentWorkout = false
    @State private var presentCreatePlan = false
    @State private var selectedPlan: WorkoutPreset?
    @State private var planPendingEdit: WorkoutPreset?
    @State private var planPendingDelete: WorkoutPreset?
    @State private var errorMessage: String?

    private var workouts: WorkoutRepository { WorkoutRepository(context: modelContext) }
    private var presets: PresetRepository { PresetRepository(context: modelContext) }

    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(spacing: Spacing.xl) {
                    quickStartSection
                    workoutPlansSection
                }
                .padding()
            }
            .background(Color.appBg.ignoresSafeArea())
            .scrollBounceBehavior(.always)
            .navigationTitle("Start Workout")
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

    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Quick Start")
                .font(.appTitle)
                .foregroundStyle(Color.primaryHeadingTxt)

            Button {
                handleStartTapped()
            } label: {
                HStack(spacing: Spacing.lg) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(activeWorkouts.isEmpty ? "Start a Workout" : "Resume Workout")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        Text(activeWorkouts.isEmpty ? "No active session" : "Workout in progress")
                            .font(.appCaption)
                            .opacity(0.75)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.primaryBtn)
                        .frame(width: 52, height: 52)
                        .background(Color.primaryBtnTxt, in: .circle)
                }
                .foregroundStyle(Color.primaryBtnTxt)
                .padding(22)
                .background(Color.primaryBtn)
                .clipShape(RoundedRectangle(cornerRadius: Radius.hero, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom)
    }

    private var workoutPlansSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .center) {
                Text("Workout Plans")
                    .font(.appTitle)
                    .foregroundStyle(Color.primaryHeadingTxt)

                Spacer()

                Button {
                    presentCreatePlan = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.primaryBtnTxt)
                        .padding(10)
                        .background(Color.primaryBtn, in: .circle)
                }
            }

            LazyVGrid(columns: columns, spacing: 16) {
                if savedPlans.isEmpty {
                    AddPlanCard()
                        .onTapGesture { presentCreatePlan = true }
                } else {
                    ForEach(savedPlans) { plan in
                        WorkoutTemplateCard(plan: plan) {
                            selectedPlan = plan
                        }
                        .onTapGesture {
                            planPendingEdit = plan
                        }
                    }
                }
            }
            .confirmationDialog(
                selectedPlan?.name ?? "Plan",
                isPresented: Binding(
                    get: { selectedPlan != nil },
                    set: { if !$0 { selectedPlan = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let plan = selectedPlan {
                    Button("Start Workout") {
                        handleStartFromPlanTapped(plan)
                        selectedPlan = nil
                    }
                    Button("Delete Plan", role: .destructive) {
                        planPendingDelete = plan
                        selectedPlan = nil
                    }
                    Button("Cancel", role: .cancel) {
                        selectedPlan = nil
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



struct WorkoutTemplateCard: View {
    let plan: WorkoutPreset
    var onOptions: () -> Void

    var body: some View {
        // Color.clear forced to a square takes the full grid-column width, so
        // the card is a true 1:1 tile regardless of its content height.
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    ExerciseThumbnail(muscleGroup: plan.orderedExercises.first?.muscleGroup)

                    Text(plan.name)
                        .font(.appHeadline)
                        .foregroundStyle(Color.primaryHeadingTxt)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        // No decode — a direct relationship count.
                        Text("\(plan.exercises.count) exercises")
                            .font(.appCaption)
                            .foregroundStyle(Color.secondaryTxt)

                        Group {
                            if let lastActive = plan.lastActive {
                                Text("Done: \(lastActive.formatted(.relative(presentation: .named)))")
                            } else {
                                Text("Never completed")
                            }
                        }
                        .font(.appMicro)
                        .foregroundStyle(Color.secondaryTxt.opacity(0.85))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding()
            }
            .appCard()
            .overlay(alignment: .topTrailing) {
                Button(action: onOptions) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.accentText)
                        .padding(8)
                        .background(Color.accentSoft, in: Capsule())
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Plan options")
                .accessibilityHint("Start, delete, or view options for \(plan.name)")
                .padding(6)
            }
    }
}

// Shown in place of the plan grid when the user has no saved plans:
// one square cell, same footprint as WorkoutTemplateCard, drawn as a dashed
// outline in the accent colour.
struct AddPlanCard: View {
    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                Text("Tap to Add a Plan")
                    .font(.appHeadline)
                    .foregroundStyle(Color.accentText)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            .background(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(
                        Color.accentText,
                        style: StrokeStyle(lineWidth: 1.5, dash: [6])
                    )
            )
            .contentShape(Rectangle())
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Add a plan")
    }
}

#Preview {
    let container = try! ModelContainer.inMemory(seeded: false)
    return HomeView()
        .modelContainer(container)
}
