//
//  RestTimerPickerSheet.swift
//  DidWeights
//
//  Quick-select presets and the custom wheel picker are mutually exclusive:
//  touching one clears the other.
//

import SwiftUI

struct RestTimerPickerSheet: View {
    let timer: RestTimerModel
    @Environment(\.dismiss) private var dismiss

    // A device setting, not workout data — @AppStorage, not SwiftData.
    @AppStorage("restTimer.preferredDuration") private var preferredDuration: Double =
        RestTimerPreset.sixtySeconds.duration

    // Left unset so onAppear can seed it from @AppStorage.
    @State private var selectedPreset: RestTimerPreset?
    @State private var customMinutes = 0
    @State private var customSeconds = 0
    @State private var useCustom = false

    private static let minuteOptions = Array(0...10)
    private static let secondOptions = Array(stride(from: 0, through: 55, by: 5))

    private var resolvedDuration: TimeInterval {
        if useCustom {
            return TimeInterval(customMinutes * 60 + customSeconds)
        }
        return selectedPreset?.duration ?? 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: .threeX) {
                    quickSelectSection
                    customDurationSection
                }
                .padding(.twoX)
            }
            .background(Color(.neutral))
            .navigationTitle("Rest Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    preferredDuration = resolvedDuration
                    timer.start(duration: resolvedDuration)
                    dismiss()
                } label: {
                    Text("Start \(Self.durationString(resolvedDuration)) Rest")
                        .primaryActionLabel()
                }
                .buttonStyle(.plain)
                .disabled(resolvedDuration <= 0)
                .opacity(resolvedDuration <= 0 ? 0.5 : 1)
                .padding(.twoX)
                .background(.bar)
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            if selectedPreset == nil && !useCustom {
                selectedPreset = RestTimerPreset.allCases.first { $0.duration == preferredDuration }
                    ?? .sixtySeconds
            }
        }
    }

    private var quickSelectSection: some View {
        HStack(spacing: .oneX) {
            ForEach(RestTimerPreset.allCases) { preset in
                RestTimerPresetPill(
                    preset: preset,
                    isSelected: !useCustom && selectedPreset == preset
                ) {
                    useCustom = false
                    selectedPreset = preset
                }
            }
        }
        .padding(.twoX)
        .appCard()
    }

    private var customDurationSection: some View {
        VStack(alignment: .leading, spacing: .oneX) {
            Text("Custom Duration")
                .font(.appHeadline)
                .foregroundStyle(Color.primaryHeadingTxt)

            HStack(spacing: 0) {
                Picker("Minutes", selection: $customMinutes) {
                    ForEach(Self.minuteOptions, id: \.self) { value in
                        Text("\(value) min").tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .onChange(of: customMinutes) { markCustomActive() }

                Picker("Seconds", selection: $customSeconds) {
                    ForEach(Self.secondOptions, id: \.self) { value in
                        Text("\(value) sec").tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .onChange(of: customSeconds) { markCustomActive() }
            }
            .frame(height: 120)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.twoX)
        .appCard()
    }

    private func markCustomActive() {
        useCustom = true
        selectedPreset = nil
    }

    private static func durationString(_ duration: TimeInterval) -> String {
        let seconds = max(0, Int(duration))
        let m = seconds / 60
        let s = seconds % 60
        return m > 0 ? String(format: "%d:%02d", m, s) : "\(s)s"
    }
}

#Preview {
    RestTimerPickerSheet(timer: RestTimerModel())
}
