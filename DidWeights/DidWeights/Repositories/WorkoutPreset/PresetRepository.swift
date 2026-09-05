//
//  PresetRepository.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-09-05.
//

import Foundation
import SwiftData

@MainActor
struct PresetRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // Every method below touches `exercises` and `exerciseOrder` together,
    // never one without the other. `exerciseOrder` always mirrors the
    // sequence of `exercises` exactly, by id — nothing outside this file
    // is allowed to set either property, per M2/M8.

    @discardableResult
    func create(name: String, exercises: [Exercise], defaultSetCount: Int) throws -> WorkoutPreset {
        let preset = WorkoutPreset(name: name, defaultSetCount: defaultSetCount)
        preset.exercises = exercises
        preset.exerciseOrder = exercises.map { $0.id }

        context.insert(preset)
        try context.save()

        return preset
    }

    func update(_ preset: WorkoutPreset, name: String, exercises: [Exercise], defaultSetCount: Int) throws {
        preset.name = name
        preset.defaultSetCount = defaultSetCount
        preset.exercises = exercises
        preset.exerciseOrder = exercises.map { $0.id }

        try context.save()
    }

    func delete(_ preset: WorkoutPreset) throws {
        context.delete(preset)
        try context.save()
    }
}
