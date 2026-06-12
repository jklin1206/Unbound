// UNBOUND/Models/ProgramBlock.swift
import Foundation

struct ProgramBlock: Codable, Identifiable, Equatable {
    let id: String
    let userId: String
    let programId: String
    let blockNumber: Int
    let startedAt: Date
    var endedAt: Date?
    let scanId: String?
    var accessoryBias: [MuscleGroup: Int]
    var cutModeActive: Bool
    var biasRefreshedFromPrevious: Bool
    var exerciseRotationsThisBlock: [String]

    init(
        id: String,
        userId: String,
        programId: String,
        blockNumber: Int,
        startedAt: Date,
        endedAt: Date? = nil,
        scanId: String?,
        accessoryBias: [MuscleGroup: Int] = [:],
        cutModeActive: Bool = false,
        biasRefreshedFromPrevious: Bool = false,
        exerciseRotationsThisBlock: [String] = []
    ) {
        self.id = id
        self.userId = userId
        self.programId = programId
        self.blockNumber = blockNumber
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.scanId = scanId
        self.accessoryBias = accessoryBias
        self.cutModeActive = cutModeActive
        self.biasRefreshedFromPrevious = biasRefreshedFromPrevious
        self.exerciseRotationsThisBlock = exerciseRotationsThisBlock
    }
}
