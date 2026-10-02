//
//  WorkoutTemplateCard.swift
//  DidWeights
//
//  The full-width card for one saved WorkoutPreset: icon, name, a combined
//  exercise-count/last-active subtitle, a "Start Routine" button, and an
//  "..." button that opens PlanOptionsPopoverContent for Edit/Delete.
//

import SwiftData
import SwiftUI

struct WorkoutTemplateCard: View {
    let plan: WorkoutPreset
    var onStart: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void

    @State private var showOptions = false

    private var subtitle: String {
        let doneText = plan.lastActive.map { "Done: \($0.formatted(.relative(presentation: .named)))" }
            ?? "Never completed"
        return "\(plan.exercises.count) exercises • \(doneText)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .oneAndAHalfX) {
            HStack(alignment: .top) {
                ExerciseThumbnail(muscleGroup: plan.orderedExercises.first?.muscleGroup)

                Spacer()

                Button {
                    showOptions = true
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.accentText)
                        .padding(.oneX)
                        .background(Color(.tertiary), in: Capsule())
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Plan options")
                .accessibilityHint("Edit or delete \(plan.name)")
                .popover(isPresented: $showOptions, attachmentAnchor: .point(.top), arrowEdge: .bottom) {
                    PlanOptionsPopoverContent(
                        planName: plan.name,
                        onEdit: { showOptions = false; onEdit() },
                        onDelete: { showOptions = false; onDelete() }
                    )
                    .presentationCompactAdaptation(.popover)
                }
            }

            Text(plan.name)
                .font(.appHeadline)
                .foregroundStyle(Color.primaryHeadingTxt)
                .lineLimit(1)

            Text(subtitle)
                .font(.appCaption)
                .foregroundStyle(Color.secondaryTxt)

            Button(action: onStart) {
                HStack {
                    Text("Start Routine")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.appHeadline.weight(.bold))
                .foregroundStyle(Color.primaryHeadingTxt)
                .padding(.horizontal, .twoX)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color(.tertiary), in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.twoX)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }
}

/// Content of the "..." popover — plan name header, then Edit/Delete rows.
/// Styled with the app's own tokens rather than system defaults, centered to
/// match the reference design; backgrounded with a translucent material
/// (not `.appCard()`'s opaque surface) so it doesn't double up on the
/// popover's own arrow/shadow chrome and so whatever it's floating over
/// shows faintly through, as in the reference image.
private struct PlanOptionsPopoverContent: View {
    let planName: String
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            Text(planName)
                .font(.appHeadline)
                .foregroundStyle(Color.primaryHeadingTxt)
                .lineLimit(1)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, .twoX)
                .padding(.vertical, .oneAndAHalfX)

            Divider().background(Color.hairline)

            optionRow("Edit Plan", color: Color.accentText, action: onEdit)
            Divider().background(Color.hairline)
            optionRow("Delete Plan", color: .red, action: onDelete)
        }
        .frame(width: 240)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(Color.hairline, lineWidth: 1)
        )
    }

    private func optionRow(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.appBody)
                .foregroundStyle(color)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, .twoX)
                .padding(.vertical, .oneAndAHalfX)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let container = try! ModelContainer.inMemory(seeded: true)
    let plan = try! container.mainContext.fetch(FetchDescriptor<WorkoutPreset>()).first!

    WorkoutTemplateCard(plan: plan, onStart: {}, onEdit: {}, onDelete: {})
        .padding()
        .background(Color(.neutral))
        .modelContainer(container)
}
