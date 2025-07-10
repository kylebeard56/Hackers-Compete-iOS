//
//  Firebase+Generic.swift
//  Hackers
//
//  Created by Kyle Beard on 11/10/22.
//

import Firebase
import FirebaseAuth
import FirebaseFirestoreCombineSwift
import Foundation

extension FirebaseServiceV2 {
    
    // MARK: - GET

    @discardableResult
    func getOne<T: Decodable>(of type: T, with query: Query) async -> Result<T, Error> {
        print("Firebase \(#function) \(type.self) \(query)")
        do {
            let querySnapshot = try await query.getDocuments()
            
            if let document = querySnapshot.documents.first {
                let data = try document.data(as: T.self)
                return .success(data)
            } else {
                print("Warning: \(#function) document not found")
                addBreadcrumb(.error, .firebase, #function, HackersError.documentNotFound)
                return .failure(HackersError.documentNotFound)
            }
        } catch let error {
            print("Error: \(#function) couldn't access snapshot documents, \(error)")
            addBreadcrumb(.error, .firebase, #function, error)
            return .failure(error)
        }
    }
    
    @discardableResult
    func getMany<T: Decodable>(of type: T,with query: Query) async -> Result<[T], Error> {
        print("Firebase \(#function) \(type.self) \(query)")
        do {
            var response: [T] = []
            let querySnapshot = try await query.getDocuments()
            
            for document in querySnapshot.documents {
                do {
                    let data = try document.data(as: T.self)
                    response.append(data)
                } catch let error {
                    print("Error: \(#function) document not decoded from data, \(error)")
                    addBreadcrumb(.error, .firebase, #function, error)
                    return .failure(error)
                }
            }
            return .success(response)
        } catch let error {
            print("Error: couldn't access snapshot documents, \(error)")
            addBreadcrumb(.error, .firebase, #function, error)
            return .failure(error)
        }
    }
    
    // MARK: - POST

    @discardableResult
    func post<T: FirebaseIdentifiable>(_ value: T, to collection: String, cache: Bool) async -> Result<T, Error> {
        print("Firebase \(#function)")
        let ref = database.collection(collection).document()
        var newValue: T = value
        newValue.id = ref.documentID
        do {
            try ref.setData(from: newValue)
            if cache { await RealmService.shared.write(newValue, to: collection) }
            return .success(newValue)
        } catch let error {
            print("Error: \(#function) in collection: \(collection), \(error)")
            addBreadcrumb(.error, .firebase, #function, error)
            return .failure(error)
        }
    }
    
    // MARK: - PUT
    
    @discardableResult
    func put<T: FirebaseIdentifiable>(_ value: T, to collection: String, cache: Bool) async -> Result<T, Error> {
        print("Firebase \(#function)")
        let ref = database.collection(collection).document(value.id)
        do {
            try ref.setData(from: value)
            if cache { await RealmService.shared.write(value, to: collection) }
            return .success(value)
        } catch let error {
            print("Error: \(#function) in \(collection) for id: \(value.id), \(error)")
            addBreadcrumb(.error, .firebase, #function, error)
            return .failure(error)
        }
    }
    
    // MARK: - DELETE
    
    @discardableResult
    func delete<T: FirebaseIdentifiable>(_ value: T, in collection: String, cache: Bool) async -> Result<Bool, Error> {
        print("Firebase \(#function)")
        let ref = database.collection(collection).document(value.id)
        do {
            try await ref.delete()
            if cache { await RealmService.shared.delete(value) }
            return .success(true)
        } catch let error {
            print("Error: \(#function) in \(collection) for id: \(value.id), \(error)")
            addBreadcrumb(.error, .firebase, #function, error)
            return .failure(error)
        }
    }
}
