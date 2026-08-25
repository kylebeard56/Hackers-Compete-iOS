//
//  ConditionalModifier.swift
//  Hackers
//
//  Created by Kyle Beard on 3/7/26.
//

import Foundation

// MARK: - Conditional Modifier

/// A predicate + effect pair that conditionally modifies scoring values in the pipeline.
/// e.g. "If birdie or better, double the points."
struct ConditionalModifier: Codable, Hashable {
    var predicate: ScoringPredicate
    var effect: ModifierEffect
    var scope: AggregationScope

    init(
        predicate: ScoringPredicate,
        effect: ModifierEffect,
        scope: AggregationScope = .perHole
    ) {
        self.predicate = predicate
        self.effect = effect
        self.scope = scope
    }
}

// MARK: - Scoring Predicate

/// Declarative predicate evaluated against scoring context.
/// Designed for JSON serialization so AI can generate predicates.
indirect enum ScoringPredicate: Codable, Hashable {
    /// Score relative to par meets a comparison. e.g. scoreToPar <= -1 means birdie or better.
    case scoreToPar(ComparisonOp, Int)
    /// Raw gross strokes meet a comparison.
    case rawStrokes(ComparisonOp, Int)
    /// All players in the scoring unit satisfy a nested predicate.
    case allPlayersMatch(ScoringPredicate)
    /// A named event occurred (for event-based scoring).
    case eventOccurred(String)

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case type, op, value, predicate, eventName
    }

    private enum PredicateType: String, Codable {
        case scoreToPar = "score_to_par"
        case rawStrokes = "raw_strokes"
        case allPlayersMatch = "all_players_match"
        case eventOccurred = "event_occurred"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(PredicateType.self, forKey: .type)
        switch type {
        case .scoreToPar:
            let op = try container.decode(ComparisonOp.self, forKey: .op)
            let value = try container.decode(Int.self, forKey: .value)
            self = .scoreToPar(op, value)
        case .rawStrokes:
            let op = try container.decode(ComparisonOp.self, forKey: .op)
            let value = try container.decode(Int.self, forKey: .value)
            self = .rawStrokes(op, value)
        case .allPlayersMatch:
            let nested = try container.decode(ScoringPredicate.self, forKey: .predicate)
            self = .allPlayersMatch(nested)
        case .eventOccurred:
            let name = try container.decode(String.self, forKey: .eventName)
            self = .eventOccurred(name)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .scoreToPar(let op, let value):
            try container.encode(PredicateType.scoreToPar, forKey: .type)
            try container.encode(op, forKey: .op)
            try container.encode(value, forKey: .value)
        case .rawStrokes(let op, let value):
            try container.encode(PredicateType.rawStrokes, forKey: .type)
            try container.encode(op, forKey: .op)
            try container.encode(value, forKey: .value)
        case .allPlayersMatch(let nested):
            try container.encode(PredicateType.allPlayersMatch, forKey: .type)
            try container.encode(nested, forKey: .predicate)
        case .eventOccurred(let name):
            try container.encode(PredicateType.eventOccurred, forKey: .type)
            try container.encode(name, forKey: .eventName)
        }
    }
}

// MARK: - Comparison Operator

enum ComparisonOp: String, Codable {
    case lessThan = "lt"
    case lessThanOrEqual = "lte"
    case equal = "eq"
    case greaterThanOrEqual = "gte"
    case greaterThan = "gt"

    func evaluate(_ lhs: Int, _ rhs: Int) -> Bool {
        switch self {
        case .lessThan:            return lhs < rhs
        case .lessThanOrEqual:     return lhs <= rhs
        case .equal:               return lhs == rhs
        case .greaterThanOrEqual:  return lhs >= rhs
        case .greaterThan:         return lhs > rhs
        }
    }

    func evaluate(_ lhs: Double, _ rhs: Double) -> Bool {
        switch self {
        case .lessThan:            return lhs < rhs
        case .lessThanOrEqual:     return lhs <= rhs
        case .equal:               return lhs == rhs
        case .greaterThanOrEqual:  return lhs >= rhs
        case .greaterThan:         return lhs > rhs
        }
    }
}

// MARK: - Modifier Effect

/// The effect applied when a predicate evaluates to true.
enum ModifierEffect: Codable, Hashable {
    case multiply(Double)
    case add(Double)
    case replace(Double)

    func apply(to value: Double) -> Double {
        switch self {
        case .multiply(let factor): return value * factor
        case .add(let amount):      return value + amount
        case .replace(let newVal):  return newVal
        }
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case type, value
    }

    private enum EffectType: String, Codable {
        case multiply, add, replace
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(EffectType.self, forKey: .type)
        let value = try container.decode(Double.self, forKey: .value)
        switch type {
        case .multiply: self = .multiply(value)
        case .add:      self = .add(value)
        case .replace:  self = .replace(value)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .multiply(let v):
            try container.encode(EffectType.multiply, forKey: .type)
            try container.encode(v, forKey: .value)
        case .add(let v):
            try container.encode(EffectType.add, forKey: .type)
            try container.encode(v, forKey: .value)
        case .replace(let v):
            try container.encode(EffectType.replace, forKey: .type)
            try container.encode(v, forKey: .value)
        }
    }
}
