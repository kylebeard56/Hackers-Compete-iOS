//
//  Untitled.swift
//  Hackers
//
//  Created by Kyle Beard on 7/10/25.
//

import Firebase
import FirebaseFirestoreCombineSwift
import Foundation

// MARK: - Fetching

extension FirebaseService {
    @discardableResult
    func fetchDocument<T: FirebaseIdentifiable>(with reference: DocumentReference) async -> Result<T, Error> {
        do {
            let data = try await reference.getDocument().data(as: T.self)
            return .success(data)
        } catch {
            self.addBreadcrumb(.error, .firebase, "Error fetching document: \(error)")
            return .failure(error)
        }
    }
    
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
}

// MARK: - Fetch Helpers

extension FirebaseService {
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
    func fetchByName<T: FirebaseIdentifiable>(
        prefix: String,
        in collection: String,
        limit: Int = 50
    ) async -> Result<[T], Error> {

        // Normalize input exactly like stored keys
        let normalized = prefix.normalizedForSearch
        let tokens = normalized.split(separator: " ").map(String.init)

        guard let first = tokens.first, !first.isEmpty else {
            return .failure(HackersError.documentNotFound)
        }

        let endPrefix = first + "\u{f8ff}"

        addBreadcrumb("GET / \(collection) tokenized search, input=\(prefix), normalized=\(normalized), tokens=\(tokens)")

        let db = Firestore.firestore()

        do {
            // Firestore prefix search on forward key ("given family")
            let forwardQuery = db.collection(collection)
                .whereField("name.search_key", isGreaterThanOrEqualTo: first)
                .whereField("name.search_key", isLessThanOrEqualTo: endPrefix)
                .limit(to: limit)

            // Firestore prefix search on reverse key ("family given")
            let reverseQuery = db.collection(collection)
                .whereField("name.search_key_reverse", isGreaterThanOrEqualTo: first)
                .whereField("name.search_key_reverse", isLessThanOrEqualTo: endPrefix)
                .limit(to: limit)

            async let forwardSnap = forwardQuery.getDocuments()
            async let reverseSnap = reverseQuery.getDocuments()

            let (f, r) = try await (forwardSnap, reverseSnap)

            var candidates: [T] = []
            candidates.append(contentsOf: f.documents.compactMap { try? $0.data(as: T.self) })
            candidates.append(contentsOf: r.documents.compactMap { try? $0.data(as: T.self) })

            // Dedup by ID
            var uniqueById: [String: T] = [:]
            for item in candidates { uniqueById[item.id] = item }
            var results = Array(uniqueById.values)

            // Multi-token client-side filtering:
            // Remaining tokens must match prefixes in either search_key or reverse
            if tokens.count > 1 {
                let rest = tokens.dropFirst()

                results = results.filter { item in
                    guard let mirror = Mirror(reflecting: item).children.first(where: { $0.label == "name" }),
                          let name = mirror.value as? Name else {
                              return false
                          }

                    let forwardKey = name.searchKey      // your stored "given family"
                    let reverseKey = name.searchKeyReverse // your stored "family given"

                    return rest.allSatisfy { t in
                        forwardKey.contains(t) || reverseKey.contains(t)
                    }
                }
            }

            if results.isEmpty {
                addBreadcrumb(.info, .firebase, "No matches for tokens: \(tokens)")
                return .failure(HackersError.documentNotFound)
            }

            return .success(Array(results.prefix(limit)))

        } catch {
            addBreadcrumb(.error, .firebase, #function, error)
            return .failure(error)
        }
    }

    @discardableResult
    func fetchByIDs<T: FirebaseIdentifiable>(
        _ ids: [String],
        in collection: String
    ) async -> Result<[T], Error> {
        addBreadcrumb("GET / \(collection) using IDs: \(ids)")

        guard !ids.isEmpty else { return .success([]) }

        do {
            // Firestore only allows up to 10 IDs in an `in` query
            var allResults: [T] = []
            for chunk in ids.chunked(into: 10) {
                let snapshot = try await Firestore.firestore()
                    .collection(collection)
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments()

                let items = snapshot.documents.compactMap { try? $0.data(as: T.self) }
                allResults.append(contentsOf: items)
            }

            return .success(allResults)
        } catch {
            addBreadcrumb(.error, .firebase, #function, error)
            return .failure(error)
        }
    }
}

// MARK: - CRUD Operations

extension FirebaseService {
    
    // MARK: - FirebaseIdentifiable
    
    @discardableResult
    func createDocument<T: FirebaseIdentifiable>(_ value: T, in collection: String) async -> Result<T, Error> {
        let ref: DocumentReference
        var newValue = value
        
        if newValue.id.isEmpty {
            ref = Firestore.firestore().collection(collection).document()
            newValue.id = ref.documentID
        } else {
            ref = Firestore.firestore().collection(collection).document(newValue.id)
        }
        
        do {
            try await ref.setData(newValue.toDictionary())
            return .success(newValue)
        } catch {
            self.addBreadcrumb(.error, .firebase, "Error creating document in collection \(collection): \(error)")
            return .failure(error)
        }
    }
    
    @discardableResult
    func batchDocuments<T: FirebaseIdentifiable>(_ values: [T], in collection: String) async -> Result<[T], Error> {
        guard !values.isEmpty else { return .success([]) }

        let db = Firestore.firestore()
        let batch = db.batch()

        var createdValues: [T] = []
        createdValues.reserveCapacity(values.count)

        do {
            for var value in values {
                let ref: DocumentReference

                if value.id.isEmpty {
                    ref = db.collection(collection).document()
                    value.id = ref.documentID
                } else {
                    ref = db.collection(collection).document(value.id)
                }

                try batch.setData(value.toDictionary(), forDocument: ref)
                createdValues.append(value)
            }

            try await batch.commit()
            return .success(createdValues)

        } catch {
            self.addBreadcrumb(.error, .firebase, "Error batching documents in collection \(collection): \(error)")
            return .failure(error)
        }
    }

    
    @discardableResult
    func updateDocument<T: FirebaseIdentifiable>(_ value: T, in collection: String) async -> Result<T, Error> {
        let ref = Firestore.firestore().collection(collection).document(value.id)
        do {
            var v = value
            v.lastUpdatedAt = .init()
            try await ref.setData(v.toDictionary())
            return .success(v)
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
    
    // MARK: - FirebaseSubcollectable
    
    @discardableResult
    func updateDocument<T: FirebaseSubcollectable>(_ value: T) async -> Result<T, Error> {
        let ref = T.documentReference(id: value.id, parentID: value.parentID)
        
        do {
            var v = value
            v.lastUpdatedAt = .init()
            try await ref.setData(v.toDictionary())
            return .success(v)
        } catch {
            self.addBreadcrumb(.error, .firebase, "Error creating document in collection \(value.collection): \(error)")
            return .failure(error)
        }
    }
    
    @discardableResult
    func deleteDocument<T: FirebaseSubcollectable>(_ value: T) async -> Result<Bool, Error> {
        let ref = T.documentReference(id: value.id, parentID: value.parentID)
        do {
            try await ref.delete()
            return .success(true)
        } catch {
            self.addBreadcrumb(.error, .firebase, "Error deleting document in \(value.collection): \(error)")
            return .failure(error)
        }
    }
}

// MARK: - FirebaseIdentifiable

protocol FirebaseIdentifiable: Identifiable, Hashable, Equatable, Codable, Sendable, Loggable {
    var id: String { get set }
    var collection: String { get }
    var createdAt: Time { get set }
    var lastUpdatedAt: Time { get set }
    var schema: Int { get }
}

extension FirebaseIdentifiable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
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

extension Array where Element: FirebaseIdentifiable {
    @discardableResult
    func batchPost() async -> Result<[Element], Error> {
        guard let first = self.first else { return .success([]) }

        let collection = first.collection
        first.addBreadcrumb("BATCH CREATE FI | \(collection.uppercased())")
        printPretty(self)

        return await FirebaseService.shared.batchDocuments(self, in: collection)
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

// MARK: - FirebaseSubcollectable

protocol FirebaseSubcollectable: FirebaseIdentifiable {
    var parentID: String { get set }
    static var parentCollection: String { get }
    static var subcollectionName: String { get }
}

extension FirebaseSubcollectable {
    // Override FirebaseIdentifable collection property with full path (likely not used due to instancing with Firebase)
    var collection: String {
        "\(Self.parentCollection)/\(parentID)/\(Self.subcollectionName)"
    }
    
    static func query(parentID: String) -> Query {
        return Firestore.firestore()
            .collection(Self.parentCollection)
            .document(parentID)
            .collection(Self.subcollectionName)
    }
    
    static func documentReference(id: String, parentID: String) -> DocumentReference {
        return Firestore.firestore()
            .collection(Self.parentCollection)
            .document(parentID)
            .collection(Self.subcollectionName)
            .document(id)
    }
}

extension FirebaseSubcollectable {
    @discardableResult func post() async -> Result<Self, Error> {
        addBreadcrumb("POST | \(collection.uppercased())")
        printPretty(self)
        let post = await FirebaseService.shared.updateDocument(self)
        return post
    }

    @discardableResult func put() async -> Result<Self, Error> {
        var document = self
        document.lastUpdatedAt = .init()
        addBreadcrumb("PUT | \(collection.uppercased())")
        printPretty(document)
        return await FirebaseService.shared.updateDocument(document)
    }

    @discardableResult func delete() async -> Result<Bool, Error> {
        addBreadcrumb("DELETE | \(collection.uppercased())")
        printPretty(self)
        return await FirebaseService.shared.deleteDocument(self)
    }
}
