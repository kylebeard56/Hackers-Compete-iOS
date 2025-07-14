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


//var isPasswordVerified: Bool = false
//var adminMode: Bool = false
//let vipCode: String = "TEEQUILATIME"

nonisolated(unsafe) var deviceUUID: String = ""
nonisolated(unsafe) var systemVersion = ""

class AppDelegate: NSObject, UIApplicationDelegate, ObservableObject, Loggable {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        print("Hackers Golf is teeing up for \(AppEnvironment.name.uppercased())...")
        storeDeviceUUID()
        storeSystemVersion()
        configureDefaults()
        configureFirebase()
        configureSentry()
        
        return true
    }
    
    private func storeDeviceUUID() {
        if let deviceID = UIDevice.current.identifierForVendor?.uuidString {
            deviceUUID = deviceID
            addBreadcrumb("Device UUID: \(deviceUUID)")
        }
    }
    
    private func storeSystemVersion() {
        Task {
            await MainActor.run {
                systemVersion = UIDevice.current.systemVersion
                addBreadcrumb("Device iOS Version: \(systemVersion)")
            }
        }
    }
    
    private func configureDefaults() {
        Task {
            await Defaults.shared.incrementLaunchCount()
        }
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
            
            // Enable all experimental features
//            options.attachViewHierarchy = true
//            options.enableMetricKit = true
//            options.enableTimeToFullDisplayTracing = true
//            options.swiftAsyncStacktraces = true
//            options.enableAppLaunchProfiling = true
        }

        SentrySDK.configureScope({ scope in
            scope.setTag(value: "deviceGUID", key: deviceUUID)
            scope.setTag(value: "locale", key: Locale.current.description)
        })
    }
}
