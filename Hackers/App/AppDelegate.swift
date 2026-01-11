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

nonisolated(unsafe) var deviceUUID: String = ""
nonisolated(unsafe) var systemVersion = ""
nonisolated(unsafe) var isRunningInPreview: Bool {
    ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
}

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
        
        //try? AuthService.shared.logout()
        
        return true
    }
    
    private func storeDeviceUUID() {
        print(#function)
        if let deviceID = UIDevice.current.identifierForVendor?.uuidString {
            deviceUUID = deviceID
            addBreadcrumb(message: "Device UUID: \(deviceUUID)")
        }
    }
    
    private func storeSystemVersion() {
        print(#function)
        Task {
            await MainActor.run {
                systemVersion = UIDevice.current.systemVersion
                addBreadcrumb(message: "Device iOS Version: \(systemVersion)")
            }
        }
    }
    
    private func configureDefaults() {
        print(#function)
        Task {
            await Defaults.shared.incrementLaunchCount()
        }
    }
    
    private func configureFirebase() {
        print(#function)
        guard let filePath = Bundle.main.path(forResource: AppEnvironment.googleServiceFileName, ofType: "plist"),
              let options = FirebaseOptions(contentsOfFile: filePath)
        else {
            self.addBreadcrumb(
                level: .error,
                message: "Google info.plist not found",
                parameters: [
                    "Google plist": AppEnvironment.googleServiceFileName,
                    "Environment": AppEnvironment.name
                ]
            )
            fatalError("Couldn't load Google Service info plist file")
        }
        FirebaseApp.configure(options: options)
    }
    
    /// To test the Sentry configuration, run `SentrySDK.crash()` when NOT connected to the Xcode debugger. Remove or
    /// comment out and then re-launch the app to send the crash reports to the Sentry dashboard. Sentry will not
    /// receieve the crash report if the Xcode debugger is actively connected to the iPhone otherwise.
    private func configureSentry() {
        print(#function)
        SentrySDK.start { options in
            options.dsn = "https://06c09f6fc6ec44949250d33033d1255e@o1318782.ingest.sentry.io/4504035028303872"
            options.debug = false//AppEnvironment.current == .development
            options.tracesSampleRate = 0.69
            options.environment = AppEnvironment.name.lowercased()
            
            // Enable all experimental features
            options.attachViewHierarchy = true
            options.enableMetricKit = true
            options.enableTimeToFullDisplayTracing = true
            options.swiftAsyncStacktraces = true
            //options.enableAppLaunchProfiling = true
        }

        SentrySDK.configureScope({ scope in
            scope.setTag(value: "deviceGUID", key: deviceUUID)
            scope.setTag(value: "locale", key: Locale.current.description)
        })
    }
}
