//
//  MainViewController.swift
//  SampleApp
//
//  Created by Ping Identity on 17/01/2022.
//  Copyright © 2022 Ping Identity. All rights reserved.
//

import UIKit
import PingOneSDK

class MainViewController: UIViewController {

    private var spinner = UIActivityIndicatorView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        initLoadingAnimation()
    }
    
    // MARK: Loading Spinner methods
    
    func initLoadingAnimation() {
        if #available(iOS 13.0, *) {
            self.spinner.style = .medium
        } else {
            self.spinner.style = .gray
        }
        self.view.addSubview(spinner)
        
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        
        spinner.isHidden = true
    }
    
    func startLoadingAnimation() {
        DispatchQueue.main.async {
            self.spinner.isHidden = false
            self.spinner.startAnimating()
        }
    }
    
    func stopLoadingAnimation() {
        DispatchQueue.main.async {
            self.spinner.isHidden = true
            self.spinner.stopAnimating()
        }
    }
    
    // MARK: handle QR Auth methods
    
    func approveUser(userId: String, authObject: AuthenticationObject) {
        startLoadingAnimation()
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let status = try await authObject.approve(userId: userId)
                await MainActor.run {
                    self.stopLoadingAnimation()
                    Alert.genericApproveWithDismiss(viewController: self, title: nil, message: status, error: nil) {
                        self.dismissToRoot()
                    }
                }
            } catch {
                await MainActor.run {
                    self.stopLoadingAnimation()
                    Alert.genericApproveWithDismiss(viewController: self, title: nil, message: nil, error: error as NSError) {
                        self.dismissToRoot()
                    }
                }
            }
        }
    }
    
    func denyUser(userId: String, authObject: AuthenticationObject) {
        startLoadingAnimation()
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let status = try await authObject.deny(userId)
                await MainActor.run {
                    self.stopLoadingAnimation()
                    Alert.genericApproveWithDismiss(viewController: self, title: nil, message: status, error: nil) {
                        self.dismissToRoot()
                    }
                }
            } catch {
                await MainActor.run {
                    self.stopLoadingAnimation()
                    Alert.genericApproveWithDismiss(viewController: self, title: nil, message: nil, error: error as NSError) {
                        self.dismissToRoot()
                    }
                }
            }
        }
    }
    
    func dismissToRoot() {
        self.navigationController?.popToRootViewController(animated: true)
    }
    
}
