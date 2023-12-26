//
//  PasskeysViewController.swift
//  SampleApp
//
//  Copyright © 2023 Ping Identity. All rights reserved.
//

import UIKit
import AuthenticationServices

@available(iOS 16.0, *)
class PasskeysViewController: MainViewController {

    var passkeysUsernameTextField: UITextField?
    var passkeysPasswordTextField: UITextField?
    private var signInObserver: NSObjectProtocol?
    private var needSignUpObserver: NSObjectProtocol?
    private var signUpObserver: NSObjectProtocol?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        signInObserver = NotificationCenter.default.addObserver(forName: .UserSignedIn, object: nil, queue: nil) {_ in
            self.didFinishSignIn()
        }
        needSignUpObserver = NotificationCenter.default.addObserver(forName: .UserNeedSignUp, object: nil, queue: nil) {_ in
            self.userNeedSignUp()
        }
        signUpObserver = NotificationCenter.default.addObserver(forName: .UserSignedUp, object: nil, queue: nil) {_ in
            self.didFinishSignUp()
        }
    }
    
    @IBAction func onButtonTapped(_ sender: UIButton) {
        PKDeviceFlowManager.authenticate() { error in
            DispatchQueue.main.async {
                if let error {
                    Alert.generic(viewController: self, message: nil, error: error)
                } else {
                    self.signIn()
                }
            }
        }
    }
    func signUp() {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: Passkeys.RegisterNotice, message: "", preferredStyle: .alert)
            alert.addTextField { alertTextField in
                alertTextField.placeholder = Passkeys.Username
                alertTextField.textContentType = .username
                self.passkeysUsernameTextField = alertTextField
            }
            alert.addTextField { alertTextField in
                alertTextField.placeholder = Passkeys.Password
                alertTextField.textContentType = .password
                alertTextField.isSecureTextEntry = true
                self.passkeysPasswordTextField = alertTextField
            }
            
            let action = UIAlertAction(title: Passkeys.Submit, style: .default) { action in
                guard let username = self.passkeysUsernameTextField?.text else {
                    print("Missing username")
                    return
                }
                
                guard let password = self.passkeysPasswordTextField?.text else {
                    print("Missing password")
                    return
                }
                
                PKDeviceFlowManager.register(username: username, password: password) { error in
                    DispatchQueue.main.async {
                        if let error {
                            Alert.generic(viewController: self, message: nil, error: error)
                        } else {
                            guard let window = self.view.window else { fatalError("The view was not in the app's view hierarchy!") }
                            PKDeviceFlowManager.signUp(anchor: window)
                        }
                    }
                }
            }
            
            alert.addAction(action)
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func signIn() {
        DispatchQueue.main.async {
            guard let window = self.view.window else { fatalError("The view was not in the app's view hierarchy!") }
            PKDeviceFlowManager.signIn(anchor: window)
        }
    }
    
    // MARK: Handle responses of passkeys manager
    
    func didFinishSignUp() {
        PKDeviceFlowManager.deviceGotAttestationFromOS { username, error in
            DispatchQueue.main.async {
                if let error {
                    Alert.generic(viewController: self, message: nil, error: error)
                } else if let username {
                    Alert.generic(viewController: self, message: "\(username) is registered!", error: error)
                }
            }
        }
    }
    
    func userNeedSignUp() {
        self.signUp()
    }
    func didFinishSignIn() {
        PKDeviceFlowManager.deviceGotAssertionFromOS { isSignUpRequired, error in
            if let error {
                Alert.generic(viewController: self, message: nil, error: error)
            } else if isSignUpRequired && error == nil {
                // User didn't sign-up yet
                self.signUp()
            } else {
                // User is signed-in
                guard let userName = PKDataManager.shared.username else {
                    print("Error fetching username after sign-in")
                    return
                }
                Alert.generic(viewController: self, message: "Hello \(userName)!", error: nil)
            }
        }
    }
}

extension NSNotification.Name {
    static let UserSignedIn = Notification.Name("UserSignedInNotification")
    static let UserSignedUp = Notification.Name("UserSignedUpNotification")
    static let UserNeedSignUp = Notification.Name("UserNeedSignUpNotification")
}
