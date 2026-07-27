//
//  AppDelegate.swift
//  SampleApp
//
//  Created by Ping Identity on 3/12/19.
//  Copyright © 2019 Ping Identity. All rights reserved.
//

import UIKit
import UserNotifications
import PingOneSDK
import AppAuth

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?
    var currentAuthorizationFlow: OIDExternalUserAgentSession?
    var notificationObject: NotificationObject?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        if #available(iOS 13.0, *) {
            // Always adopt a light interface style.
            window!.overrideUserInterfaceStyle = .light
        }
        setUpPingOneSDK()
        registerRemoteNotifications()

        return true
    }
    
    func setUpPingOneSDK() {
        // Configure for NorthAmerica in this case, but can be configured to any PingOneGeo
        Task {
            do {
                try await PingOne.configure(geo: .NorthAmerica)
            } catch {
                print((error as NSError).debugDescription)
            }
        }
    }
    
    func registerRemoteNotifications() {
        print("Registering remote notifications")
        
        let center  = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.sound, .alert, .badge]) { (granted, error) in
            if error == nil {
                // Registering UNNotificationCategories more than once results in previous categories being overwritten. PingOne provides the needed categories. The developer may add categories.
                UNUserNotificationCenter.current().setNotificationCategories(PingOne.getUNNotificationCategories())
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print(error.localizedDescription)
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        
        let deviceTokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("Device Token: \(deviceTokenString)")

        var deviceTokenType: PingOne.APNSDeviceTokenType = .production
        #if DEBUG
        deviceTokenType = .sandbox
        #endif
        
        Task {
            let errors = await PingOne.setDeviceToken(token: deviceToken, type: deviceTokenType)
            if let errors {
                for error in errors {
                    print(error.debugDescription)
                }
            }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        print("didReceive")
        
        Task {
            do {
                let notificationObject = try await PingOne.processRemoteNotificationAction(response.actionIdentifier, authenticationMethod: "user", forRemoteNotification: response.notification.request.content.userInfo)
                if let notificationObject = notificationObject, let userInfo = response.notification.request.content.userInfo as? [String: Any] {
                    let title = self.getNotificationTextFrom(userInfo).title
                    let message = self.getNotificationTextFrom(userInfo).body
                    await MainActor.run {
                        self.displayNotificationViewAlert(notificationObject, title: title, msg: message)
                    }
                }
            } catch {
                let nsError = error as NSError
                print("Error: \(String(describing: nsError))")
                if nsError.code == ErrorCode.unrecognizedRemoteNotification.rawValue {
                    // Do something else with remote notification.
                }
            }

            await MainActor.run {
                completionHandler()
            }
        }
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("didReceiveRemoteNotification userinfo: \(userInfo)")
        
        Task {
            let fetchResult: UIBackgroundFetchResult

            do {
                let notificationObject = try await PingOne.processRemoteNotification(userInfo)
                if let notificationObject = notificationObject {
                    self.notificationObject = notificationObject
                    switch notificationObject.notificationType {
                    case .authentication:
                        if let userInfo = userInfo as? [String: Any] {
                            let title = self.getNotificationTextFrom(userInfo).title
                            let message = self.getNotificationTextFrom(userInfo).body
                            await MainActor.run {
                                self.displayNotificationViewAlert(notificationObject, title: title, msg: message)
                            }
                            fetchResult = .newData
                        } else {
                            fetchResult = .noData
                        }
                    case .authCanceled:
                        await self.removeTopViewAsync()
                        fetchResult = .noData
                    default:
                        fetchResult = .noData
                    }
                } else {
                    fetchResult = .noData
                }
            } catch {
                let nsError = error as NSError
                print("Error: \(String(describing: nsError))")
                if nsError.code == ErrorCode.unrecognizedRemoteNotification.rawValue {
                    // Unrecognized remote notification.
                }
                fetchResult = .noData
            }

            completionHandler(fetchResult)
        }
    }
    
    func getNotificationTextFrom(_ userInfo: [String: Any]) -> (title: String, body: String) {
        
        if let aps = userInfo[Push.aps] as? [String: Any] {
            if let alert = aps[Push.alert] as? [String: String] {
                if let title = alert[Push.title], let body = alert[Push.body] {
                     return (title, body)
                }
            }
        }
        return ("", "")
    }
    
    func displayNotificationViewAlert(_ notificationObject: NotificationObject, title: String, msg: String) {
        DispatchQueue.main.async {
            self.removeTopView({
                var displayOnVc: UIViewController
                guard let rootVc = self.window?.rootViewController else {
                    return
                }
                
                if rootVc.presentedViewController != nil {
                    displayOnVc = rootVc.presentedViewController!
                } else {
                    displayOnVc = rootVc
                }
                
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "notificationRecived"), object: nil)
                
                if notificationObject.numberMatchingType == Push.NumberMatchingOptions || notificationObject.numberMatchingType == Push.NumberMatchingManual {
                    // Authentication with number matching
                    Alert.numberMatching(viewController: displayOnVc, type: notificationObject.numberMatchingType, title: Local.NumMatchingPick, numberMatchingList: notificationObject.numberMatchingOptions) { pickedNumber in
                        self.approveNumMatching(displayOnVc: displayOnVc, notificationObject: notificationObject, numberPicked: pickedNumber, title: title, message: msg)
                    }
                } else {
                    // Authentication with approve / deny
                    Alert.approveDeny(viewController: displayOnVc, title: title, message: msg) { (approved) in
                        if let approved = approved {
                            if approved {
                                Task {
                                    do {
                                        let _ = try await notificationObject.approve(withAuthenticationMethod: "user")
                                    } catch {
                                        await MainActor.run {
                                            Alert.generic(viewController: displayOnVc, message: msg, error: error as NSError)
                                        }
                                    }
                                }
                            } else {
                                Task {
                                    do {
                                        try await notificationObject.deny(reason: .none)
                                    } catch {
                                        await MainActor.run {
                                            Alert.generic(viewController: displayOnVc, message: msg, error: error as NSError)
                                        }
                                    }
                                }
                            }
                        }
                        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "notificationResponded"), object: nil)
                    }
                }
            })
        }
    }
    
    func approveNumMatching(displayOnVc: UIViewController, notificationObject: NotificationObject, numberPicked: Int, title: String, message: String) {
        Task {
            do {
                let _ = try await notificationObject.approve(withAuthenticationMethod: "user", numberMatchingPickedValue: numberPicked)
            } catch {
                await MainActor.run {
                    Alert.generic(viewController: displayOnVc, message: message, error: error as NSError)
                }
            }
        }
    }

    @MainActor
    private func removeTopViewAsync() async {
        await withCheckedContinuation { continuation in
            self.removeTopView {
                continuation.resume()
            }
        }
    }
    
    func removeTopView(_ completionHandler: @escaping () -> Void) {
        guard let window: UIWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow }), var topVC = window.rootViewController?.presentedViewController else {
            completionHandler()
            return
        }
        while topVC.presentedViewController != nil {
            topVC = topVC.presentedViewController!
        }
        if let alertVC = topVC as? UIAlertController {
            alertVC.dismiss(animated: false, completion: {
                completionHandler()
            })
            return
        }
        completionHandler()
    }
    
    // OIDC
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {

        if let authorizationFlow = self.currentAuthorizationFlow, authorizationFlow.resumeExternalUserAgentFlow(with: url) {
            self.currentAuthorizationFlow = nil
            return true
        }

        return false
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
    }

    func applicationWillTerminate(_ application: UIApplication) {
    }
}
