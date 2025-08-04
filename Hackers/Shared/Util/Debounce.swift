//
//  Debounce.swift
//  Hackers
//
//  Created by Kyle Beard on 7/10/25.
//

import Combine
import UIKit

class Debounce<T>: ObservableObject {
    @Published var value: T
    @Published var debouncedValue: T
    
    private var subscription = Set<AnyCancellable>()
    
    init(value: T, milliseconds: Int = 500) {
        self.value = value
        self.debouncedValue = value
        
        $value
            .debounce(for: .milliseconds(milliseconds), scheduler: DispatchQueue.main)
            .sink(receiveValue: { [weak self] value in self?.debouncedValue = value })
            .store(in: &subscription)
    }
}

