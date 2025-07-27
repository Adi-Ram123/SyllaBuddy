//
//  NotificationsSettingsViewController.swift
//  SyllaBuddy
//
//  Created by Vincent Vo on 7/15/25.
//

import UIKit
import UserNotifications

class NotificationsSettingsViewController: UIViewController {

    @IBOutlet weak var pushSwitch: UISwitch!
    @IBOutlet weak var homeworkSwitch: UISwitch!
    @IBOutlet weak var examSwitch: UISwitch!

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        ThemeManager.shared.applyAll(to: self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Notifications"
        
        // Load saved states
        pushSwitch.isOn = UserDefaults.standard.bool(forKey: "pushEnabled")
        homeworkSwitch.isOn = UserDefaults.standard.bool(forKey: "homeworkEnabled")
        examSwitch.isOn = UserDefaults.standard.bool(forKey: "examEnabled")
    }

    @IBAction func pushSwitchToggled(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: "pushEnabled")
        showNotificationStatus(name: "Push Notifications", isOn: sender.isOn)
    }
    
    @IBAction func homeworkSwitchToggled(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: "homeworkEnabled")
        showNotificationStatus(name: "Homework Notifications", isOn: sender.isOn)
    }
    
    @IBAction func examSwitchToggled(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: "examEnabled")
        showNotificationStatus(name: "Exam Notifications", isOn: sender.isOn)
    }
    
    
    private func showNotificationStatus(name: String, isOn: Bool) {
        let status = isOn ? "enabled" : "disabled"
        print("\(name) are now \(status).")
        
        let alert = UIAlertController(
            title: name,
            message: "\(name) have been \(status).",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
