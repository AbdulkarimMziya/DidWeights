//
//  PersistanceHelper.swift
//  DidWeights
//
//  Created by Abdulkarim Mziya on 2026-06-06.
//

import Foundation

enum SerializationError: Error {
    case encodingFailed
    case decodingFailed
}

class PersistanceHelper {
    
    static func transformToData(_ loggedWorkout: LoggedWorkout) throws -> Data {
        let encoder = JSONEncoder()
        do {
            return try encoder.encode(loggedWorkout)
        } catch {
            throw SerializationError.encodingFailed
        }
    }
    
    static func transformFromData(_ data: Data) throws -> LoggedWorkout {
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(LoggedWorkout.self, from: data)
        } catch {
            throw SerializationError.decodingFailed
        }
    }
}
