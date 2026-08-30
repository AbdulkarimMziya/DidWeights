//
//  WorkoutRepositoryTests.swift
//  DidWeightsTests
//
//  Created by Abdulkarim Mziya on 2026-08-27.
//

import Foundation
import SwiftData
import Testing
@testable import DidWeights

@MainActor
@Suite struct WorkoutRepositoryTests {
    // Keep a strong reference to the container alive for the lifetime of
    // each test instance — Swift Testing creates a fresh struct instance
    // per @Test, so this plays the same role makeSUT() would have.
    private let container: ModelContainer
    private let context: ModelContext
    private let sut: WorkoutRepository

    init() throws {
        let container = try ModelContainer.inMemory(seeded: false)
        let context = container.mainContext

        self.container = container
        self.context = context
        self.sut = WorkoutRepository(context: context)
    }

    @Test func startingEmptyWorkoutInsertsOneOpenWorkout() throws {
        try sut.startEmptyWorkout(named: "Push Day")

        let descriptor = FetchDescriptor<Workout>()
        let allWorkouts = try context.fetch(descriptor)

        #expect(allWorkouts.count == 1)
        #expect(allWorkouts.first?.endDate == nil)
    }

    @Test func startingWorkoutWhileAnotherIsActive() throws {
        try sut.startEmptyWorkout(named: "Push Day")

        #expect(throws: WorkoutRepositoryError.workoutAlreadyActive) {
            try sut.startEmptyWorkout(named: "Leg Day")
        }

        let descriptor = FetchDescriptor<Workout>()
        let allWorkouts = try context.fetch(descriptor)

        #expect(allWorkouts.count == 1)
        #expect(allWorkouts.first?.name == "Push Day")
        #expect(allWorkouts.first?.endDate == nil)
    }

    @Test func startingFromWorkoutPreset() throws {
        // Arrange: create exercises and insert them to establish identifiers
        let squat = Exercise(name: "Barbell Squat")
        let legExtension = Exercise(name: "Leg Extension")

        context.insert(squat)
        context.insert(legExtension)

        // Arrange: create and configure the preset
        let preset = WorkoutPreset(name: "Leg Day", defaultSetCount: 3)
        context.insert(preset)

        preset.exercises = [squat, legExtension]
        preset.exerciseOrder = [squat.id, legExtension.id]

        // Act
        try sut.startWorkout(from: preset)

        // Assert: the workout exists and is linked to the preset
        let descriptor = FetchDescriptor<Workout>()
        let allWorkouts = try context.fetch(descriptor)

        #expect(allWorkouts.count == 1)
        #expect(allWorkouts.first?.preset?.name == "Leg Day")

        // Assert: exactly 6 total ExerciseSets exist globally (2 exercises * 3 sets)
        let setDescriptor = FetchDescriptor<ExerciseSet>()
        let allSets = try context.fetch(setDescriptor)
        #expect(allSets.count == 6)

        // Assert: the workout's orderedSets are sequential, 0 to 5
        guard let orderedWorkoutSets = allWorkouts.first?.orderedSets else {
            Issue.record("Workout was created but had no valid sets array wrapper.")
            return
        }

        #expect(orderedWorkoutSets.count == 6)

        for index in 0..<orderedWorkoutSets.count {
            #expect(orderedWorkoutSets[index].order == index)
        }

        // Assert: grouping matches preset order — Squat's sets first, then Leg Extension's
        let firstGroup = orderedWorkoutSets[0...2].compactMap { $0.exercise }
        let secondGroup = orderedWorkoutSets[3...5].compactMap { $0.exercise }

        #expect(firstGroup.allSatisfy { $0.id == squat.id })
        #expect(secondGroup.allSatisfy { $0.id == legExtension.id })
    }
    
    @Test func finishStampsEndDateAndMovesQueryMembership() throws {
        let activeWorkout = try sut.startEmptyWorkout(named: "Push Day")
        try sut.finish(activeWorkout)
        
        let allActiveWorkoutsDescriptor = FetchDescriptor<Workout>(
            predicate: #Predicate<Workout> { workout in
                workout.endDate == nil
            }
        )
        
        let allCompleteWorkoutsDescriptor = FetchDescriptor<Workout>(
            predicate: #Predicate<Workout> { workout in
                workout.endDate != nil
            }
        )
        
        let allActiveWorkouts = try context.fetch(allActiveWorkoutsDescriptor)
        let allCompletedWorkouts = try context.fetch(allCompleteWorkoutsDescriptor)
        
        #expect(allActiveWorkouts.count == 0)
        #expect(allCompletedWorkouts.count == 1)
    }
    
    @Test func finishStampsPresetLastActiveNotStart() throws {
        let squat = Exercise(name: "Barbell Squat")
        context.insert(squat)
        
        let preset = WorkoutPreset(name: "Leg Day", defaultSetCount: 3)
        context.insert(preset)
        
        preset.exercises = [squat]
        preset.exerciseOrder = [squat.id]
        
        #expect(preset.lastActive == nil)
        
        let workout = try sut.startWorkout(from: preset)
        
        #expect(preset.lastActive == nil)
        
        let targetFinishDate = Date(timeIntervalSince1970: 1787961600) // Deterministic date anchor
        try sut.finish(workout, at: targetFinishDate)
        
        #expect(preset.lastActive != nil)
        #expect(preset.lastActive == targetFinishDate)
    }

    @Test func finishingAlreadyFinishedWorkoutThrowsAndDoesNotRestamp() throws {
        // 1. Arrange: Start an empty workout with a deterministic start date
        let referenceStartDate = Date(timeIntervalSince1970: 1787961600)
        let workout = try sut.startEmptyWorkout(named: "Push Day", at: referenceStartDate)
        
        // 2. Act: Finish the workout for the first time at a distinct completion timestamp
        let initialFinishDate = referenceStartDate.addingTimeInterval(3600) // 1 hour later
        try sut.finish(workout, at: initialFinishDate)
        
        // 3. Capture: Lock down the valid end date before triggering the failure path
        let firstEndDate = workout.endDate
        #expect(firstEndDate == initialFinishDate)
        
        // 4. Act & Assert Part 1: Verify attempting to finish it again throws the correct error
        let redundantFinishDate = initialFinishDate.addingTimeInterval(1800) // Attempted re-stamp 30 minutes later
        #expect(throws: WorkoutRepositoryError.workoutAlreadyFinished) {
            try sut.finish(workout, at: redundantFinishDate)
        }
        
        // 5. Act & Assert Part 2: Confirm the original completion timestamp remained completely pristine
        #expect(workout.endDate == firstEndDate)
        #expect(workout.endDate != redundantFinishDate)
    }
    
    @Test func finishPrunesUntouchedSetsAndRenumbersDensely() throws {
        // 1. Arrange: Create and insert an exercise prerequisite
        let benchPress = Exercise(name: "Bench Press")
        context.insert(benchPress)
        
        // 2. Arrange: Create a preset configured to generate exactly 3 sets
        let preset = WorkoutPreset(name: "Chest Day", defaultSetCount: 3)
        context.insert(preset)
        preset.exercises = [benchPress]
        preset.exerciseOrder = [benchPress.id]
        
        // 3. Act: Initialize the workout (automatically inserts 3 ExerciseSets with orders 0, 1, 2)
        let workout = try sut.startWorkout(from: preset)
        
        // Retrieve the generated sets from the workout context to modify them
        let initialSets = workout.orderedSets
        #expect(initialSets.count == 3)
        
        let setZero = initialSets[0] // Order 0
        let setOne = initialSets[1]  // Order 1 <- We will leave this untouched
        let setTwo = initialSets[2]  // Order 2
        
        // 4. Act: Touch Set 0 and Set 2 directly to ensure they survive
        setZero.reps = 10
        setZero.weight = 135.0
        setZero.isCompleted = true
        
        setTwo.reps = 8
        setTwo.weight = 145.0
        setTwo.isCompleted = true
        
        // Double check that Set 1 matches your exact "untouched" invariant rule
        #expect(setOne.reps == nil && setOne.weight == nil && setOne.isCompleted == false)
        
        // 5. Act: Complete the workout sequence
        try sut.finish(workout)
        
        // 6. Assert: Verify the untouched set (Set 1) was completely pruned from the context
        let setDescriptor = FetchDescriptor<ExerciseSet>()
        let remainingGlobalSets = try context.fetch(setDescriptor)
        #expect(remainingGlobalSets.count == 2)
        
        // 7. Assert: Verify the workout's relationship collection is densified
        let postFinishOrderedSets = workout.orderedSets
        #expect(postFinishOrderedSets.count == 2)
        
        // 8. Assert: Strict Verification of structural ordering properties: [0, 1] instead of [0, 2]
        #expect(postFinishOrderedSets[0].id == setZero.id)
        #expect(postFinishOrderedSets[0].order == 0)
        
        #expect(postFinishOrderedSets[1].id == setTwo.id)
        #expect(postFinishOrderedSets[1].order == 1) // Confirm index compressed densely down from 2
    }

    @Test func cancelDeletesWorkoutAndCascadesSets() throws {
        // 1. Arrange: Create and insert an exercise prerequisite
        let benchPress = Exercise(name: "Bench Press")
        context.insert(benchPress)
        
        // 2. Arrange: Create a preset configured to generate sets
        let preset = WorkoutPreset(name: "Chest Day", defaultSetCount: 2)
        context.insert(preset)
        preset.exercises = [benchPress]
        preset.exerciseOrder = [benchPress.id]
        
        // 3. Arrange: Start a workout from the preset to create relationships
        let workout = try sut.startWorkout(from: preset)
        
        // Verify the setup created the child sets before running the mutation
        let preCancelSets = try context.fetch(FetchDescriptor<ExerciseSet>())
        #expect(preCancelSets.count == 2)
        
        // 4. Act: Cancel the current workout session
        try sut.cancel(workout)
        
        // 5. Assert: Verify the parent Workout is completely gone
        let remainingWorkouts = try context.fetch(FetchDescriptor<Workout>())
        #expect(remainingWorkouts.isEmpty)
        
        // 6. Assert: Verify the cascade rule completely erased all related child ExerciseSets
        let remainingSets = try context.fetch(FetchDescriptor<ExerciseSet>())
        #expect(remainingSets.isEmpty)
    }
    
    @Test func pauseThenResumeExcludesPausedSpanFromElapsed() throws {
        // 1. Arrange: Define a fixed timeline using a static reference date
        let baseStartDate = Date(timeIntervalSinceNow: 0)
        let workout = try sut.startEmptyWorkout(named: "Push Day", at: baseStartDate)
        
        // 2. Act: Pause after exactly 60 seconds of initial activity
        let pauseDate = baseStartDate.addingTimeInterval(60)
        try sut.pause(workout, at: pauseDate)
        
        // 3. Act: Resume the workout exactly 30 seconds later
        let resumeDate = pauseDate.addingTimeInterval(30) // baseStartDate + 90 seconds
        try sut.resume(workout, at: resumeDate)
        
        // 4. Act: Choose an observation checkpoint further down the timeline
        let checkpointDate = baseStartDate.addingTimeInterval(200)
        let actualElapsed = workout.elapsed(asOf: checkpointDate)
        
        // 5. Assert: Calculate the expected active time
        // Absolute Time (200s) - Paused Interval (30s) = 170 seconds
        let expectedElapsed: TimeInterval = 170.0
        
        // Use an explicit margin of error allowance to accommodate floating-point variations safely
        #expect(abs(actualElapsed - expectedElapsed) < 0.001)
    }

    @Test func pausingAlreadyPausedWorkoutThrows() throws {
        // 1. Arrange: Start a fresh workout session
        let workout = try sut.startEmptyWorkout(named: "Push Day")
        
        // 2. Act: Pause the active workout for the first time
        try sut.pause(workout)
        
        // Verify the state machine flags the pause accurately
        #expect(workout.isPaused == true)
        
        // 3. Act & Assert: Verify that a redundant pause attempt throws the correct validation error
        #expect(throws: WorkoutRepositoryError.alreadyPaused) {
            try sut.pause(workout)
        }
    }
    
    // MARK: Test for  Composition **/
    
    @Test func addSetAssignsIncreasingUniqueOrder() throws {

        let workout = try sut.startEmptyWorkout(named: "Leg Day")
        let squat = Exercise(name: "Squat")
        context.insert(squat)
        
        for _ in 0...2 {
            try sut.addSet(to: workout, exercise: squat)
        }
        
        #expect(Set(workout.orderedSets).count == 3)
        
        let orderedIds = workout.orderedSets.compactMap { $0.order }
        #expect( orderedIds == [0,1,2] )
        
    }
    
    @Test func addSetToFirstExerciseShiftsSubsequentOrder() throws {
        
        let workout = try sut.startEmptyWorkout(named: "Upper Day")
        
        let pullUp = Exercise(name: "Pull Ups")
        let rows = Exercise(name: "Rows")
        let latPullDown = Exercise(name: "Lat Pull Downs",)
        context.insert(pullUp)
        context.insert(rows)
        context.insert(latPullDown)
        try sut.addExercise(pullUp, to: workout, setCount: 1)
        try sut.addExercise(rows, to: workout, setCount: 1)
        try sut.addExercise(latPullDown, to: workout, setCount: 1)
        
        try sut.addSet(to: workout, exercise: pullUp)
    
        let orderedSets = workout.orderedSets
        #expect(orderedSets.count == 4)
        
        let exerciseGroups = workout.exerciseGroups
        let firstExercise = exerciseGroups.first
        #expect(firstExercise?.sets.count == 2)
        
        try sut.addSet(to: workout, exercise: rows)
        try sut.addSet(to: workout, exercise: latPullDown)
        
        let orderedExercises = exerciseGroups.compactMap { $0.exercise }
        #expect( orderedExercises == [pullUp,rows,latPullDown])
        
    }
    
    @Test func removeSetLeavesRemainingSetsDenselyOrdered() throws {
        // 1. Arrange: Start an empty workout and create a placeholder exercise
        let workout = try sut.startEmptyWorkout(named: "Leg Day")
        let legPress = Exercise(name: "Leg Press")
        context.insert(legPress)
        
        // 2. Arrange: Generate exactly 3 sequential sets (assigned orders: 0, 1, 2)
        let setZero = try sut.addSet(to: workout, exercise: legPress)
        let setOne = try sut.addSet(to: workout, exercise: legPress)
        let setTwo = try sut.addSet(to: workout, exercise: legPress)
        
        // Baseline check before running the deletion mutation
        let initialSets = workout.orderedSets
        #expect(initialSets.count == 3)
        #expect(initialSets[0].id == setZero.id && initialSets[0].order == 0)
        #expect(initialSets[1].id == setOne.id && initialSets[1].order == 1)
        #expect(initialSets[2].id == setTwo.id && initialSets[2].order == 2)
        
        // 3. Act: Remove the intermediate middle record (setOne)
        try sut.removeSet(setOne)
        
        // 4. Assert: Verify the total remaining collection count compressed down
        let postRemoveSets = workout.orderedSets
        #expect(postRemoveSets.count == 2)
        
        // 5. Assert: Verify dense, continuous indexing rules hold true [0, 1] instead of [0, 2]
        #expect(postRemoveSets[0].id == setZero.id)
        #expect(postRemoveSets[0].order == 0) // Should stay untouched
        
        #expect(postRemoveSets[1].id == setTwo.id)
        #expect(postRemoveSets[1].order == 1) // Must compress down from index index 2 to 1
    }
    
    @Test func twoActiveWorkoutsCausesActiveWorkoutToThrow() throws {
        // 1. Arrange: Start the first active workout normally through the repository
        try sut.startEmptyWorkout(named: "First Workout")
        
        // 2. Arrange: Manually break the system invariant!
        // Construct and insert a second active workout directly into the context, bypassing the repo.
        let rogueWorkout = Workout(name: "Second Active Workout", startDate: .now)
        context.insert(rogueWorkout)
        
        // 3. Act & Assert: Verify that activeWorkout() catches the corrupt state and throws
        #expect(throws: WorkoutRepositoryError.multipleActiveWorkouts) {
            try sut.activeWorkout()
        }
    }

    @Test func togglingCompletionWithoutRepsThrows() throws {
        // 1. Arrange: Start an empty workout session and insert a target exercise
        let workout = try sut.startEmptyWorkout(named: "Push Day")
        let benchPress = Exercise(name: "Bench Press")
        context.insert(benchPress)
        
        // 2. Arrange: Add a new set to the workout (reps and weight are nil by default)
        let set = try sut.addSet(to: workout, exercise: benchPress)
        #expect(set.reps == nil)
        #expect(set.isCompleted == false)
        
        // 3. Act & Assert Part 1: Verify that toggling completion throws the correct error
        #expect(throws: WorkoutRepositoryError.setNotCompletable) {
            try sut.toggleCompletion(of: set)
        }
        
        // 4. Act & Assert Part 2: Confirm the set state remains unchanged after the failure
        #expect(set.isCompleted == false)
        #expect(set.completedAt == nil)
    }
    
    @Test func togglingCompletionTwiceRestoresOriginalState() throws {
        // 1. Arrange: Start a workout session and insert a placeholder exercise
        let workout = try sut.startEmptyWorkout(named: "Push Day")
        let benchPress = Exercise(name: "Bench Press")
        context.insert(benchPress)
        
        // 2. Arrange: Add a set and update it with valid rep metrics
        let set = try sut.addSet(to: workout, exercise: benchPress)
        try sut.updateSet(set, reps: 10, weight: 135.0)
        #expect(set.isCompleted == false)
        
        // 3. Act: Toggle completion for the first time (going from Incomplete -> Complete)
        try sut.toggleCompletion(of: set)
        
        // Assert: Verify it shifts into a completed state with a timestamp stamp
        #expect(set.isCompleted == true)
        #expect(set.completedAt != nil)
        
        // 4. Act: Toggle completion a second time (going from Complete -> Incomplete)
        try sut.toggleCompletion(of: set)
        
        // Assert: Verify it cleanly restores back to its uncompleted state
        #expect(set.isCompleted == false)
        #expect(set.completedAt == nil)
    }

    @Test func removeExerciseOnlyAffectsSetsInThatWorkout() throws {
        // 1. Arrange: Create and insert a single shared exercise type
        let sharedExercise = Exercise(name: "Barbell Squat")
        context.insert(sharedExercise)
        
        // 2. Arrange: Start the first active workout using standard repository paths
        let workoutA = try sut.startEmptyWorkout(named: "Workout A")
        
        // 3. Arrange: Bypass the repo lifecycle rule to insert Workout B directly into data storage
        let workoutB = Workout(name: "Workout B", startDate: .now)
        context.insert(workoutB)
        
        // 4. Act: Add exactly 2 sets to each separate workout container using the shared exercise
        try sut.addExercise(sharedExercise, to: workoutA, setCount: 2)
        try sut.addExercise(sharedExercise, to: workoutB, setCount: 2)
        
        // Verify baseline setup values before running the deletion mutation
        #expect(workoutA.sets.count == 2)
        #expect(workoutB.sets.count == 2)
        
        // 5. Act: Remove the exercise exclusively from the first workout container (Workout A)
        try sut.removeExercise(sharedExercise, from: workoutA)
        
        // 6. Assert: Verify Workout A was completely stripped of its matching sets
        #expect(workoutA.sets.isEmpty)
        
        // 7. Assert: Verify Workout B's relationships remained pristine and untouched
        #expect(workoutB.sets.count == 2)
        
        // Explicitly verify Workout B's child elements still match the shared exercise identity
        let workoutBSets = workoutB.orderedSets
        #expect(workoutBSets.allSatisfy { $0.exercise?.id == sharedExercise.id })
    }
    
    // MARK: Test for Derived Accessors **/
    @Test func exerciseGroupsOrdersGroupsByFirstAppearance() throws {
        // 1. Arrange: Start an empty workout and create two placeholder exercises
        let workout = try sut.startEmptyWorkout(named: "Pull Day")
        let exerciseA = Exercise(name: "Pull Ups")
        let exerciseB = Exercise(name: "Rows")
        
        context.insert(exerciseA)
        context.insert(exerciseB)
        
        // 2. Arrange: Intentionally insert Exercise B's set into the context FIRST in real time
        let setB = ExerciseSet(order: 1, workout: workout, exercise: exerciseB)
        context.insert(setB)
        
        // 3. Arrange: Insert Exercise A's set SECOND, but assign it a LOWER sequence order (0)
        let setA = ExerciseSet(order: 0, workout: workout, exercise: exerciseA)
        context.insert(setA)
        
        // 4. Act & Assert: Read the exerciseGroups computation property
        let groups = workout.exerciseGroups
        #expect(groups.count == 2)
        
        // 5. Assert: Verify the sort respects sequence appearance order, not database instantiation sequence
        #expect(groups[0].exercise.id == exerciseA.id) // Order 0 appears first
        #expect(groups[1].exercise.id == exerciseB.id) // Order 1 appears second
    }

    @Test func orderedSetsRespectsOrderEvenWhenRelationshipIsShuffled() throws {
        // 1. Arrange: Start an empty workout session and insert a placeholder exercise
        let workout = try sut.startEmptyWorkout(named: "Leg Day")
        let legPress = Exercise(name: "Leg Press")
        context.insert(legPress)
        
        // 2. Arrange: Manually construct and insert sets out of numeric order (2, then 0, then 1)
        let setTwo = ExerciseSet(order: 2, workout: workout, exercise: legPress)
        context.insert(setTwo)
        
        let setZero = ExerciseSet(order: 0, workout: workout, exercise: legPress)
        context.insert(setZero)
        
        let setOne = ExerciseSet(order: 1, workout: workout, exercise: legPress)
        context.insert(setOne)
        
        // 3. Act: Read the orderedSets collection property from the workout
        let finalOrderedSets = workout.orderedSets
        
        // 4. Assert: Verify exactly 3 sets exist
        #expect(finalOrderedSets.count == 3)
        
        // 5. Assert: Verify the returned array is strictly sorted by the numeric .order property
        #expect(finalOrderedSets[0].id == setZero.id)
        #expect(finalOrderedSets[0].order == 0)
        
        #expect(finalOrderedSets[1].id == setOne.id)
        #expect(finalOrderedSets[1].order == 1)
        
        #expect(finalOrderedSets[2].id == setTwo.id)
        #expect(finalOrderedSets[2].order == 2)
    }

}
