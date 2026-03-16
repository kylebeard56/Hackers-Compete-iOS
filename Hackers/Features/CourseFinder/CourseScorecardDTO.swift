//
//  CourseScorecardDTO.swift
//  Hackers
//
//  DTO for OCR scorecard JSON from Vision API (OpenAI/Anthropic).
//

import Foundation

struct CourseScorecardDTO: Decodable {
    let clubName: String?
    let courseName: String?
    let location: CourseScorecardLocationDTO?
    let tees: [CourseScorecardTeeDTO]?
}

struct CourseScorecardLocationDTO: Decodable {
    let address: String?
    let city: String?
    let state: String?
    let country: String?
    let latitude: Double?
    let longitude: Double?
}

struct CourseScorecardTeeDTO: Decodable {
    let name: String?
    let gender: String?
    let holes: [CourseScorecardHoleDTO]?
    let courseRating: Double?
    let slopeRating: Int?
}

struct CourseScorecardHoleDTO: Decodable {
    let number: Int?
    let par: Int?
    let yardage: Int?
    let handicap: Int?
}
