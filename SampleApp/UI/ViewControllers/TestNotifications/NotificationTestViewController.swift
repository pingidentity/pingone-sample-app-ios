//
//  NotificationTestViewController.swift
//  SampleApp
//
//  Copyright © 2023 Ping Identity. All rights reserved.
//

import UIKit
import PingOneSDK

class NotificationTestViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var testResultsTableView: UITableView!
    @IBOutlet weak var testResultsLbl: UILabel!
    
    var notificationTests: [NotificationTest]?
    let testsNames = [NotificationTest.TestType.tokenType.name(),
                      NotificationTest.TestType.allowNotification.name(),
                      NotificationTest.TestType.token.name(),
                      NotificationTest.TestType.notificationsSetting.name(),
                      NotificationTest.TestType.backgroundSetting.name(),
                      NotificationTest.TestType.connectivity.name(),
                      NotificationTest.TestType.categories.name(),
                      NotificationTest.TestType.testPush.name(),
                      NotificationTest.TestType.setPushPayloadToSDK.name()]
    
    let testsDelay = 1.0
    let testRowHeight = CGFloat(35.0)
    var didTestsFail = false
    var didTestFailYellow = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.testResultsTableView.dataSource = self
        self.testResultsTableView.delegate = self
        self.testResultsTableView.separatorStyle = .none
        registerTableViewCells()
        
        initTests()
    }
    
    private func registerTableViewCells() {
        let notificationTestCell = UINib(nibName: "NotificationTestCellTableViewCell", bundle: nil)
        self.testResultsTableView.register(notificationTestCell, forCellReuseIdentifier: "NotificationTestCellTableViewCell")
    }
    
    // MARK: Handle test tableview
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return testsNames.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "NotificationTestCellTableViewCell", for: indexPath) as? NotificationTestCellTableViewCell else {
            return UITableViewCell()
        }

        let testName = testsNames[indexPath.row]
        cell.testNameLbl?.text = testName
        cell.apnsTypeLbl?.text = ""
        cell.resultImageView?.image = nil
        cell.activityIndicatorView.startAnimating()
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return testRowHeight
    }
    
    func initTests() {
        PingOne.testRemoteNotification(.NorthAmerica) { notificationTests, status, error  in
            print("Test summary result is: \(status.name())")
            self.notificationTests = notificationTests
            self.runTestsHandler(notificationTests, error)
        }
    }
    
    func runTestsHandler(_ notificationTests: [NotificationTest]?, _ error: NSError?) {
        DispatchQueue.main.async {
            let length = notificationTests?.count ?? 0
            if length == 0 && error != nil {
                Alert.genericWithCompletion(viewController: self, message: nil, error: error) {
                    self.dismiss(animated: true, completion: nil)
                }
                self.someTestFailureStatus()
                return
            }
            
            guard let testsArray = notificationTests else {
                self.someTestFailureStatus()
                return
            }
            
            var counter = 0
            Timer.scheduledTimer(withTimeInterval: self.testsDelay, repeats: true) { timer in
                if self.didTestsFail {
                    timer.invalidate()
                    return
                }
                self.runSingleTest(testsArray[counter], testNumber: counter)
                counter += 1
                if counter >= length {
                    timer.invalidate()
                }
            }
        }
    }
    
    @objc private func runSingleTest(_ notificationTest: NotificationTest, testNumber: Int) {
        switch notificationTest.name {
        case NotificationTest.TestType.tokenType.name():
            let indexPath = IndexPath(row: 0, section: 0)
            guard let cell = self.testResultsTableView.cellForRow(at: indexPath) as? NotificationTestCellTableViewCell else {
                return
            }
            cell.activityIndicatorView.alpha = 0
            cell.apnsTypeLbl?.text = notificationTest.testResult == .pass ? PushTestIdentifiers.APNSSandbox : PushTestIdentifiers.APNSProduction
        
        default:
            let indexPath = IndexPath(row: testNumber, section: 0)
            updateUIForTest(notificationTest, indexPath: indexPath)
        }
    }
    
    private func updateUIForTest(_ notificationTest: NotificationTest, indexPath: IndexPath) {
        if notificationTest.testResult == .pass {
            self.showSuccess(forCellIndex: indexPath)
        } else {
            // In case only notification settings is disbled show yellow alert and continue test flow
            if notificationTest.name == NotificationTest.TestType.notificationsSetting.name() {
                self.showYellowAlert(forCellIndex: indexPath, resultInfo: notificationTest.resultsInfo)
            } else if notificationTest.name == NotificationTest.TestType.backgroundSetting.name() {
                // In case notification and background setting are disabled show failure
                if self.didTestFailYellow {
                    self.showFailure(forCellIndex: indexPath, resultInfo: notificationTest.resultsInfo)
                } else {
                    self.showYellowAlert(forCellIndex: indexPath, resultInfo: notificationTest.resultsInfo)
                }
            } else {
                self.showFailure(forCellIndex: indexPath, resultInfo: notificationTest.resultsInfo)
            }
        }
    }
    
    // MARK: Handling updating UI
    
    private func showSuccess(forCellIndex: IndexPath) {
        DispatchQueue.main.async {
            self.didTestsFail = false
            if let cell = self.testResultsTableView.cellForRow(at: forCellIndex) as? NotificationTestCellTableViewCell {
                cell.activityIndicatorView.alpha = 0
                cell.resultImageView.image = UIImage.init(named: "green_v")
            }
        }
    }
    
    private func showYellowAlert(forCellIndex: IndexPath, resultInfo: String) {
        DispatchQueue.main.async {
            self.didTestFailYellow = true
            if let cell = self.testResultsTableView.cellForRow(at: forCellIndex) as? NotificationTestCellTableViewCell {
                cell.activityIndicatorView.alpha = 0
                cell.resultImageView.image = UIImage.init(named: "yellow_x")
                self.testResultsLbl.text = "\(self.testResultsLbl.text ?? "") \n\n\(resultInfo)"
            }
        }
    }
    
    private func showFailure(forCellIndex: IndexPath, resultInfo: String) {
        DispatchQueue.main.async {
            self.someTestFailureStatus()
            self.didTestsFail = true
            if let cell = self.testResultsTableView.cellForRow(at: forCellIndex) as? NotificationTestCellTableViewCell {
                cell.activityIndicatorView.alpha = 0
                cell.resultImageView.image = UIImage.init(named: "red_x")
                self.testResultsLbl.text = "\(self.testResultsLbl.text ?? "") \n\n\(resultInfo)"
            }
        }
    }
    
    private func someTestFailureStatus() {
        for cell in testResultsTableView.visibleCells {
            if let testCell = cell as? NotificationTestCellTableViewCell {
                testCell.activityIndicatorView.isHidden = true
            }
        }
    }
    
    @IBAction func closeWasTapped(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
}
