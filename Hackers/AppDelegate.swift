//
//  AppDelegate.swift
//  Hackers
//
//  Created by Kyle Beard on 10/23/22.
//

import Firebase
import Foundation
import Sentry
import UIKit

var deviceUUID: String = ""
var isPasswordVerified: Bool = false

class AppDelegate: NSObject, UIApplicationDelegate, ObservableObject {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        print("Hackers is teeing up...")
        
        if let deviceID = UIDevice.current.identifierForVendor?.uuidString {
            deviceUUID = deviceID
            print("Device ID: \(deviceUUID)")
        }
        
        configureFirebase()
        configureSentry()
        
        return true
    }
    
    private func configureFirebase() {
        FirebaseApp.configure()
    }
    
    /// To test the Sentry configuration, run `SentrySDK.crash()` when NOT connected to the Xcode debugger. Remove or
    /// comment out and then re-launch the app to send the crash reports to the Sentry dashboard. Sentry will not
    /// receieve the crash report if the Xcode debugger is actively connected to the iPhone otherwise.
    private func configureSentry() {
        SentrySDK.start { options in
            options.dsn = "https://06c09f6fc6ec44949250d33033d1255e@o1318782.ingest.sentry.io/4504035028303872"
            options.debug = false
            options.tracesSampleRate = 0.69
            options.environment = "production"
        }

        SentrySDK.configureScope({ scope in
            scope.setTag(value: "deviceGUID", key: deviceUUID)
            scope.setTag(value: "locale", key: Locale.current.description)
        })
    }
}
