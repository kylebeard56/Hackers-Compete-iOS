//
//  Toast.swift
//  Hackers
//
//  Created by Kyle Beard on 8/11/25.
//

import AlertToast
import Foundation

// swiftlint:disable line_length
extension AlertToast {
    static func loader() -> AlertToast {
        return AlertToast(type: .loading)
    }

    static func successBanner(_ title: String, _ subtitle: String? = nil) -> AlertToast {
        let style = AlertToast.AlertStyle.style(backgroundColor: .systemBlue, titleColor: .white)
        return AlertToast(displayMode: .banner(.pop), type: .regular, title: title, subTitle: subtitle, style: style)
    }

    static func messageBanner(_ title: String, _ subtitle: String? = nil) -> AlertToast {
        let style = AlertToast.AlertStyle.style(backgroundColor: .hackersForeground, titleColor: .hackersBackground)
        return AlertToast(displayMode: .banner(.pop), type: .regular, title: title, subTitle: subtitle, style: style)
    }

    static func errorBanner(_ title: String, _ subtitle: String? = nil) -> AlertToast {
        let style = AlertToast.AlertStyle.style(backgroundColor: .systemRed, titleColor: .white)
        return AlertToast(displayMode: .banner(.pop), type: .regular, title: title, subTitle: subtitle, style: style)
    }
    
    static func successHUD(_ title: String, _ subtitle: String? = nil) -> AlertToast {
        let style = AlertToast.AlertStyle.style(backgroundColor: .systemBlue, titleColor: .white, subTitleColor: .white)
        return AlertToast(displayMode: .hud, type: .regular, title: title, subTitle: subtitle, style: style)
    }

    static func messageHUD(_ title: String, _ subtitle: String? = nil) -> AlertToast {
        let style = AlertToast.AlertStyle.style(backgroundColor: .hackersForeground, titleColor: .hackersBackground, subTitleColor: .hackersBackground)
        return AlertToast(displayMode: .hud, type: .regular, title: title, subTitle: subtitle, style: style)
    }

    static func errorHUD(_ title: String, _ subtitle: String? = nil) -> AlertToast {
        let style = AlertToast.AlertStyle.style(backgroundColor: .systemRed, titleColor: .white, subTitleColor: .white)
        return AlertToast(displayMode: .hud, type: .regular, title: title, subTitle: subtitle, style: style)
    }
    
    static func completeTile(_ title: String, _ subtitle: String? = nil) -> AlertToast {
        return AlertToast(type: .complete(.systemGreen), title: title, subTitle: subtitle)
    }
    
    static func errorTile(_ title: String, _ subtitle: String? = nil) -> AlertToast {
        return AlertToast(type: .error(.systemError), title: title, subTitle: subtitle)
    }
}
