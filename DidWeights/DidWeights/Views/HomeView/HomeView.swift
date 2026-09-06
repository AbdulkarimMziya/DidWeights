//
//  HomeView.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-06-19.
//

import SwiftData
import SwiftUI

private enum HomePalette {
    static let pageBackground = Color("AppBackground")
    static let cardBackground = Color("CardRowBG")
    static let primaryButtonBackground = Color("PrimaryBtnBG")
    static let primaryButtonText = Color("PrimaryBtnText")
    static let pillBackground = Color("PillBackground")
    static let headingText = Color("PrimaryHeadingText")
    static let secondaryText = Color("SecondaryText")
}

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Workout> { $0.endDate == nil })
    private var activeWorkouts: [Workout]

    // Retargeted onto the new schema — no more LegacySavedWorkout.
    @Query(sort: \WorkoutPreset.name) private var savedPlans: [WorkoutPreset]

    @State private var presentWorkout = false
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
                VStack(spacing: 24) {
                    // Section 1: Quick Start
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Start")
                            .font(.title2.bold())
                            .foregroundStyle(HomePalette.headingText)

                        Button {
                            handleStartTapped()
                        } label: {
                            Text(activeWorkouts.isEmpty ? "Start a Workout" : "Resume Workout")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(HomePalette.primaryButtonText)
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .background(HomePalette.primaryButtonBackground.gradient)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(HomePalette.secondaryText.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom)


                    // Section 2: Workout Plans
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .center) {
                            Text("Workout Plans")
                                .font(.title2.bold())
                                .foregroundStyle(HomePalette.headingText)

                            Spacer()

                            Button {
                                presentCreatePlan = true
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(HomePalette.primaryButtonText)
                                    .padding(10)
                                    .background(HomePalette.primaryButtonBackground, in: .circle)
                            }
                        }

                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(savedPlans) { plan in
                                WorkoutTemplateCard(plan: plan) {
                                    selectedPlan = plan
                                }
                                .onTapGesture {
                                    planPendingEdit = plan
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
                .padding()

            }
            .background(HomePalette.pageBackground.ignoresSafeArea())
            .scrollBounceBehavior(.always)
            .navigationTitle("Start Workout")
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

    private func handleStartTapped() {
        if activeWorkouts.isEmpty {
            do {
                try workouts.startEmptyWorkout(named: "Workout")
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
        VStack(alignment: .leading, spacing: 12) {
            Text(plan.name)
                .font(.headline)
                .foregroundStyle(HomePalette.headingText)
                .lineLimit(1)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                // No decode — a direct relationship count.
                Text("\(plan.exercises.count) exercises")
                    .font(.subheadline)
                    .foregroundStyle(HomePalette.secondaryText)

                Group {
                    if let lastActive = plan.lastActive {
                        Text("Done: \(lastActive.formatted(.relative(presentation: .named)))")
                    } else {
                        Text("Never completed")
                    }
                }
                .font(.caption)
                .foregroundStyle(HomePalette.secondaryText.opacity(0.85))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .background(HomePalette.cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.25), radius: 5, x: 0, y: 2)
        .overlay(alignment: .topTrailing) {
            Button(action: onOptions) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(HomePalette.primaryButtonText)
                    .padding(8)
                    .background(HomePalette.pillBackground, in: Capsule())
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Plan options")
            .accessibilityHint("Start, delete, or view options for \(plan.name)")
            .padding(6)
        }
    }
}

#Preview {
    let container = try! ModelContainer.inMemory(seeded: false)
    return HomeView()
        .modelContainer(container)
}
