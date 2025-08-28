//
//  Untitled.swift
//  Hackers
//
//  Created by Kyle Beard on 7/10/25.
//


import Firebase
import FirebaseFirestoreCombineSwift
import Foundation

// MARK: - CRUD

extension FirebaseService {
    @discardableResult
    func fetchDocument<T: FirebaseIdentifiable>(query: Query) async -> Result<T, Error> {
        do {
            let querySnapshot = try await query.getDocuments()
            guard let document = querySnapshot.documents.first else {
                self.addBreadcrumb(.error, .firebase, "Document not found for \(query)")
                return .failure(HackersError.documentNotFound)
            }
            let data = try document.data(as: T.self)
            return .success(data)
        } catch {
            self.addBreadcrumb(.error, .firebase, "Error fetching document: \(error)")
            return .failure(error)
        }
    }
    
    @discardableResult
    func fetchDocuments<T: FirebaseIdentifiable>(query: Query) async -> Result<[T], Error> {
        do {
            let querySnapshot = try await query.getDocuments()
            let documents = try querySnapshot.documents.compactMap { try $0.data(as: T.self) }
            return .success(documents)
        } catch {
            self.addBreadcrumb(.error, .firebase, "Error fetching documents: \(error)")
            return .failure(error)
        }
    }
    
    @discardableResult
    func fetch<T: FirebaseIdentifiable>(
        where field: String,
        isEqualTo value: String,
        in collection: String
    ) async -> Result<T, Error> {
        addBreadcrumb("GET / \(collection) using [\(field): \(value)]")
        do {
            let querySnapshot = try await Firestore.firestore()
                .collection(collection)
                .whereField(field, isEqualTo: value)
                .getDocuments()
            if let document = querySnapshot.documents.first {
                do {
                    let data = try document.data(as: T.self)
                    return .success(data)
                } catch let error {
                    addBreadcrumb(.error, .firebase, #function, error)
                    return .failure(error)
                }
            } else {
                addBreadcrumb(.info, .firebase, "\(T.self) not found by [\(field): \(value)]")
                return .failure(HackersError.documentNotFound)
            }
        } catch let error {
            addBreadcrumb(.error, .firebase, #function, error)
            return .failure(error)
        }
    }
    
    @discardableResult
    func fetch<T: FirebaseIdentifiable>(
        with fieldValues: [String: Any],
        in collection: String
    ) async -> Result<T, Error> {
        addBreadcrumb("GET / \(collection) using \(fieldValues)")
        do {
            let querySnapshot = Firestore.firestore().collection(collection)
            for (field, value) in fieldValues {
                querySnapshot
                    .whereField(field, isEqualTo: value)
            }
                
            if let document = try await querySnapshot.getDocuments().documents.first {
                do {
                    let data = try document.data(as: T.self)
                    return .success(data)
                } catch let error {
                    addBreadcrumb(.error, .firebase, #function, error)
                    return .failure(error)
                }
            } else {
                addBreadcrumb(.info, .firebase, "\(T.self) not found using \(fieldValues)")
                return .failure(HackersError.documentNotFound)
            }
        } catch let error {
            addBreadcrumb(.error, .firebase, #function, error)
            return .failure(error)
        }
    }
    
    @discardableResult
    func createDocument<T: FirebaseIdentifiable>(_ value: T, in collection: String) async -> Result<T, Error> {
        let ref = Firestore.firestore().collection(collection).document()
        var newValue = value
        newValue.id = ref.documentID
        
        do {
            try await ref.setData(newValue.toDictionary())
            return .success(newValue)
        } catch {
            self.addBreadcrumb(.error, .firebase, "Error creating document in collection \(collection): \(error)")
            return .failure(error)
        }
    }
    
    @discardableResult
    func updateDocument<T: FirebaseIdentifiable>(_ value: T, in collection: String) async -> Result<T, Error> {
        let ref = Firestore.firestore().collection(collection).document(value.id)
        do {
            try await ref.setData(value.toDictionary())
            return .success(value)
        } catch {
            self.addBreadcrumb(.error, .firebase, "Error updating document in collection \(collection): \(error)")
            return .failure(error)
        }
    }
    
    @discardableResult
    func deleteDocument<T: FirebaseIdentifiable>(_ value: T, from collection: String) async -> Result<Bool, Error> {
        let ref = Firestore.firestore().collection(collection).document(value.id)
        do {
            try await ref.delete()
            return .success(true)
        } catch {
            self.addBreadcrumb(.error, .firebase, "Error deleting document in \(collection): \(error)")
            return .failure(error)
        }
    }
}

// MARK: - Identifiable

protocol FirebaseIdentifiable: Identifiable, Hashable, Codable, Sendable, Loggable {
    var id: String { get set }
    var collection: String { get }
    var createdAt: Time { get set }
    var lastUpdatedAt: Time { get set }
}

extension FirebaseIdentifiable {
    @discardableResult func post() async -> Result<Self, Error> {
        addBreadcrumb("POST | \(collection.uppercased())")
        printPretty(self)
        let post = await FirebaseService.shared.createDocument(self, in: collection)
        return post
    }

    @discardableResult func put() async -> Result<Self, Error> {
        var document = self
        document.lastUpdatedAt = .init()
        addBreadcrumb("PUT | \(collection.uppercased())")
        printPretty(document)
        return await FirebaseService.shared.updateDocument(document, in: collection)
    }

    @discardableResult func delete() async -> Result<Bool, Error> {
        addBreadcrumb("DELETE | \(collection.uppercased())")
        printPretty(self)
        return await FirebaseService.shared.deleteDocument(self, from: collection)
    }
}

// MARK: - Query

extension Query {
    func whereField(useCondition: Bool, _ field: String, isEqualTo: Any) -> Query {
        return useCondition ? self.whereField(field, isEqualTo: isEqualTo) : self
    }

    func whereField(useCondition: Bool, _ field: String, isGreaterThan: Any) -> Query {
        return useCondition ? self.whereField(field, isGreaterThan: isGreaterThan) : self
    }

    func whereField(useCondition: Bool, _ field: String, arrayContains: Any) -> Query {
        return useCondition ? self.whereField(field, arrayContains: arrayContains) : self
    }

    func whereField(useCondition: Bool, _ field: String, inArray: [Any]) -> Query {
        return useCondition ? self.whereField(field, in: inArray) : self
    }
}

// MARK: - Subcollection

protocol FirebaseSubcollectable: FirebaseIdentifiable {
    var parentCollection: String { get }
    var parentID: String { get set }
    var subcollectionName: String { get }
}

extension FirebaseSubcollectable {
    // Override FirebaseIdentifable collection property with full path
    var collection: String {
        "\(parentCollection)/\(parentID)/\(subcollectionName)"
    }
}
