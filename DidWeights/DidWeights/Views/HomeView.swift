//
//  HomeView.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-06-19.
//

import SwiftUI

struct HomeView: View {
    
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
                        } label: {
                            Text("Start an Empty Workout")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .background(Color(.systemBlue).gradient)
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
                            ForEach(sampleTemplates) { template in
                                Button {
                                    //TODO: Action to open or start template
                                } label: {
                                    WorkoutTemplateCard(template: template)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding()
                
            }
            .scrollBounceBehavior(.always)
            .navigationTitle("Start Workout")
            .preferredColorScheme(.dark)
        }
    }
}




struct WorkoutTemplateCard: View {
    let template: WorkoutTemplate
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text(template.name)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
            
            Spacer(minLength: 0)
            
            // Exercise Count and Last Active Metadata
            VStack(alignment: .leading, spacing: 4) {
                Text("\(template.exerciseCount) exercises")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Group {
                    if let lastActive = template.lastActive {
                        Text("Active: \(lastActive, style: .date)")
                    } else {
                        Text("Never active")
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
    }
}


#Preview {
    HomeView()
}
