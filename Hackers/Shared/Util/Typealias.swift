//
//  Typealias.swift
//  Hackers
//
//  Created by Kyle Beard on 9/28/25.
//

/// Typealias for () -> Void
typealias Callback = () -> Void

/// Typealias for (T) -> Void
typealias CallbackValue<T> = (T) -> Void

/// Typealias for () async -> Void
typealias AsyncCallback = () async -> Void

/// Typealias for (T) async -> Void
typealias AsyncCallbackValue<T> = (T) async -> Void
