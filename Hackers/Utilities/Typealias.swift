//
//  Typealias.swift
//  Hackers
//
//  Created by Kyle Beard on 10/23/22.
//

import Foundation

typealias Hackable = ObservableObject  & Alertable & Loggable

typealias OnSelection = (() -> Void)?
typealias OnPartyCodeChange = ((String) -> Void)?
typealias OnFocusSelection = ((Bool) -> Void)?
typealias OnHoleDetailSelection = ((HoleDetails) -> Void)?
typealias OnHoleSelection = ((Int) -> Void)?
