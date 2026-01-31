//
//  ToastObserver.swift
//  Hackers
//
//  Created by Kyle Beard on 2/3/23.
//

import AlertToast
import Combine
import SwiftUI

enum ToastType {
    case success, failure
}

class ToastObserver: ObservableObject {
    @Published var success: Bool = false
    @Published var failure: Bool = false
    
    var successMessage: String
    var failureMessage: String
    
    init(success: String = "", failure: String = "") {
        successMessage = success
        failureMessage = failure
    }
    
    func present(_ type: ToastType) {
        success = type == .success
        failure = type == .failure
    }
}

struct ToastObservation: ViewModifier {
    @Binding var observer: ToastObserver
    
    func body(content: Content) -> some View {
        content
            .toast(isPresenting: $observer.success, alert: { AlertToast.messageBanner(observer.successMessage) })
            .toast(isPresenting: $observer.failure, alert: { AlertToast.errorBanner(observer.failureMessage) })
    }
}

extension View {
    func observeToast(for observer: Binding<ToastObserver>) -> some View {
        return modifier(ToastObservation(observer: observer))
    }
}
