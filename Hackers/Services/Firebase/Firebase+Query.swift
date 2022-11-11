//
//  Firebase+Query.swift
//  Hackers
//
//  Created by Kyle Beard on 11/10/22.
//

import Firebase
import FirebaseAuth
import FirebaseFirestoreSwift
import Foundation

extension Query {
    func whereField(useCondition: Bool, _ field: String, isEqualTo: Any) -> Query {
        if useCondition {
            return self.whereField(field, isEqualTo: isEqualTo)
        } else {
            return self
        }
    }
    
    func whereField(useCondition: Bool, _ field: String, isGreaterThan: Any) -> Query {
        if useCondition {
            return self.whereField(field, isGreaterThan: isGreaterThan)
        } else {
            return self
        }
    }
    
    func whereField(useCondition: Bool, _ field: String, arrayContains: Any) -> Query {
        if useCondition {
            return self.whereField(field, arrayContains: arrayContains)
        } else {
            return self
        }
    }
    
    func whereField(useCondition: Bool, _ field: String, inArray: [Any]) -> Query {
        if useCondition {
            return self.whereField(field, in: inArray)
        } else {
            return self
        }
    }
}
