//
//  SettingsView.swift
//  DidWeights
//
//  Device preferences, not workout data — every control here reads/writes
//  @AppStorage directly, matching the precedent already set by
//  RestTimerPickerSheet's "restTimer.preferredDuration" key. Nothing on this
//  screen touches modelContext.
//
//  ProfileCardView is intentionally not included below — see its own file.
//

import SwiftUI

struct SettingsView: View {
    // Weight display unit. Stored as a String (not WeightUnit directly) because
    // @AppStorage requires a primitive-backed type; WeightUnit.resolved(from:)
    // is the single place that turns a raw value back into a unit.
    @AppStorage(WeightUnit.storageKey) private var weightUnitRaw = WeightUnit.pounds.rawValue

    // Same key/default WeeklyConsistencySection reads — this is the control
    // for that value, not a second copy of it.
    @AppStorage(WeeklyConsistency.goalStorageKey) private var weeklyGoal = WeeklyConsistency.defaultGoal

    // Same key RestTimerPickerSheet already owns — this screen sets the
    // global default; the in-workout sheet still lets you override per-rest.
    @AppStorage(RestTimerPreset.storageKey) private var preferredRestDuration =
        RestTimerPreset.sixtySeconds.duration

    private var weightUnit: WeightUnit { WeightUnit.resolved(from: weightUnitRaw) }

    private var weightUnitBinding: Binding<WeightUnit> {
        Binding(
            get: { weightUnit },
            set: { weightUnitRaw = $0.rawValue }
        )
    }

    private var selectedRestPreset: RestTimerPreset {
        RestTimerPreset.allCases.first { $0.duration == preferredRestDuration } ?? .sixtySeconds
    }

    private var restPresetBinding: Binding<RestTimerPreset> {
        Binding(
            get: { selectedRestPreset },
            set: { preferredRestDuration = $0.duration }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Measurement Units") {
                    HStack {
                        Text("Weight")
                            .font(.appBody)
                            .foregroundStyle(Color.primaryHeadingTxt)
                        Spacer()
                        Picker("Weight Unit", selection: weightUnitBinding) {
                            ForEach(WeightUnit.allCases) { unit in
                                Text(unit.abbreviation).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                        .labelsHidden()
                    }
                }
                .listRowBackground(Color.cardBg)

                Section("Weekly Target") {
                    VStack(alignment: .leading, spacing: .oneX) {
                        HStack {
                            Text("Workout Days")
                                .font(.appBody)
                                .foregroundStyle(Color.primaryHeadingTxt)
                            Spacer()
                            Text("\(weeklyGoal) days/week")
                                .font(.appCaption.weight(.semibold))
                                .foregroundStyle(Color.accentText)
                                .padding(.horizontal, .oneAndAHalfX)
                                .padding(.vertical, .quarterX)
                                .background(Color(.tertiary), in: Capsule())
                        }
                        Picker("Workout Days", selection: $weeklyGoal) {
                            ForEach(WeeklyConsistency.goalOptions, id: \.self) { day in
                                Text("\(day)d").tag(day)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                }
                .listRowBackground(Color.cardBg)

                Section("Default Rest") {
                    VStack(alignment: .leading, spacing: .oneX) {
                        HStack {
                            Label("Default Rest", systemImage: "timer")
                                .font(.appBody)
                                .foregroundStyle(Color.primaryHeadingTxt)
                            Spacer()
                            Text(selectedRestPreset.label)
                                .font(.appCaption.weight(.semibold))
                                .foregroundStyle(Color.accentText)
                                .padding(.horizontal, .oneAndAHalfX)
                                .padding(.vertical, .quarterX)
                                .background(Color(.tertiary), in: Capsule())
                        }
                        Picker("Default Rest", selection: restPresetBinding) {
                            ForEach(RestTimerPreset.allCases) { preset in
                                Text(preset.label).tag(preset)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                }
                .listRowBackground(Color.cardBg)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(.neutral))
            .tint(Color.accentText)
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
