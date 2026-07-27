//
//  PasscodeViewController.swift
//  SampleApp
//
//  Copyright © 2021 Ping Identity. All rights reserved.
//

import UIKit
import PingOneSDK

class PasscodeViewController: UIViewController {

    @IBOutlet weak var passCodeLbl: UILabel!
    @IBOutlet weak var timerLbl: UILabel!
    
    var oneTimePasscodeData: OneTimePasscodeInfo?
    var passcodeTimer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = SDKFunctionality.OneTimePasscode
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        getOneTimePasscode()
    }
    
    // MARK: - OTP functions
    
    func getOneTimePasscode() {
        Task { [weak self] in
            guard let self = self else {
                return
            }

            do {
                let oneTimePasscodeData = try await PingOne.getOneTimePasscode()
                if let _ = oneTimePasscodeData?.passcode {
                    await MainActor.run {
                        self.oneTimePasscodeData = oneTimePasscodeData
                        self.initializePasscodeLabel()
                    }
                    return
                }
            } catch {
                await MainActor.run {
                    self.passCodeLbl.text = OneTimePasscodeError.notPaired
                    self.timerLbl.text = ""
                }
            }
        }
    }
    
    func initializePasscodeLabel() {
        passcodeTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(updatePasscodeTime), userInfo: nil, repeats: true)
    }
    
    @objc func updatePasscodeTime() {
        let date = Date()
        
        guard let passcodeData = self.oneTimePasscodeData else {
            return
        }
        guard isPasscodeEnded(currentdate: date, eventdate: Date(timeIntervalSince1970: passcodeData.validUntil)) == false else {
            resetOneTimePasscode()
            getOneTimePasscode()
            return
        }
        
        let remainTime = Int(passcodeData.validUntil - Date().timeIntervalSince1970)
        
        passCodeLbl.text = "\(passcodeData.passcode)"
        timerLbl.text = "\(remainTime)s"
    }
    
    func isPasscodeEnded(currentdate: Date, eventdate: Date) -> Bool {
        if currentdate >= eventdate {
            return true
        }
        return false
    }
    
    func resetOneTimePasscode() {
        passCodeLbl.text = ""
        timerLbl.text = ""
        
        passcodeTimer?.invalidate()
        passcodeTimer = nil
        oneTimePasscodeData = nil
    }
}
