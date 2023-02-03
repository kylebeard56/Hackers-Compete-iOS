//
//  SessionDebounce.swift
//  Hackers
//
//  Created by Kyle Beard on 2/3/23.
//

import Combine
import SwiftUI

class SessionDebounce: ObservableObject {
    @Published var request: Int = 0
    @Published var debouncer: Int = 0
    
    private var subscription = Set<AnyCancellable>()
    
    init() {
        $request
            .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink(receiveValue: { [weak self] value in self?.debouncer = value })
            .store(in: &subscription)
    }
}
