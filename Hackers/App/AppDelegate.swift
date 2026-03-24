//
//  AppDelegate.swift
//  Hackers
//
//  Created by Kyle Beard on 10/23/22.
//

import Firebase
import Foundation
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
        configureTelemetry()
        trackLaunchContext()
        configureDefaults()
        configureFirebase()
        
        //try? AuthService.shared.logout()
        
        return true
    }
    
    private func storeDeviceUUID() {
        print(#function)
        if let deviceID = UIDevice.current.identifierForVendor?.uuidString {
            deviceUUID = deviceID
        }
    }
    
    private func storeSystemVersion() {
        print(#function)
        systemVersion = UIDevice.current.systemVersion
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
    
    private func configureTelemetry() {
        print(#function)
        TelemetryService.shared.configure()
    }

    private func trackLaunchContext() {
        addBreadcrumb(message: "Device UUID: \(deviceUUID)")
        addBreadcrumb(message: "Device iOS Version: \(systemVersion)")
        addEvent(
            "app.launched",
            eventProps: [
                "device_uuid": deviceUUID,
                "device_operating_system": systemVersion
            ]
        )
    }
}
