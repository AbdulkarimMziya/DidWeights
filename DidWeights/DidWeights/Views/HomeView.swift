//
//  HomeView.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-06-19.
//

import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(WorkoutManager.self) private var manager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedWorkout.name) private var savedPlans: [SavedWorkout]
    
    @State private var presentWorkout = false
    @State private var presentCreatePlan = false
    @State private var selectedPlan: SavedWorkout?
    @State private var planPendingEdit: SavedWorkout?
    @State private var planPendingDelete: SavedWorkout?
    
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
                            .foregroundStyle(.secondary)
                        
                        Button {
                            // TODO: Start Empty Workout Action
                            manager.startWorkout()
                            presentWorkout = true
                        } label: {
                            Text(manager.activeWorkout == nil ? "Start a Workout" : "Resume Workout")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .background(manager.activeWorkout == nil ? Color(.systemBlue).gradient : Color(.systemGreen).gradient)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(.secondary.opacity(0.3), lineWidth: 1)
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
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Button {
                                // TODO: Create Plan
                                presentCreatePlan = true
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(10)
                                    .background(.secondary, in: .circle)
                            }
                        }
                        
                        // Workout Plan grids
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
                                    manager.startWorkout(from: plan)
                                    presentWorkout = true
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
                                        modelContext.delete(plan)
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
            .scrollBounceBehavior(.always)
            .navigationTitle("Start Workout")
            .preferredColorScheme(.dark)
            .sheet(isPresented: $presentWorkout) {
                ActiveWorkoutView()
            }
            .sheet(item: $planPendingEdit) { plan in
                CreatePlanView(editingPlan: plan)
            }
            .sheet(isPresented: $presentCreatePlan) {
                CreatePlanView()
            }
            
        }
    }
}



struct WorkoutTemplateCard: View {
    let plan: SavedWorkout
    var onOptions: () -> Void

    private var exerciseCount: Int {
        (try? PersistanceHelper.transformFromData(plan.workoutData))?.exercises.count ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(plan.name)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(exerciseCount) exercises")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Group {
                    if let lastActive = plan.lastActive {
                        Text("Done: \(lastActive.formatted(.relative(presentation: .named)))")
                    } else {
                        Text("Never completed")
                    }
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.25), radius: 5, x: 0, y: 2)
        .overlay(alignment: .topTrailing) {
            Button(action: onOptions) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(8)
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
    // 1. Create a preview instance
    let mockManager = WorkoutManager()
    
    HomeView()
        .environment(mockManager)
}
