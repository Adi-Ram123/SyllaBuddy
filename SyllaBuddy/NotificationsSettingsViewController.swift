//
//  NotificationsSettingsViewController.swift
//  SyllaBuddy
//
//  Created by Vincent Vo on 7/15/25.
//

import UIKit
import EventKit
import UserNotifications

class NotificationsSettingsViewController: UIViewController {

    @IBOutlet weak var calendarSwitch: UISwitch!
    @IBOutlet weak var eventSwitch: UISwitch!
    let eventStore = EKEventStore()
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        ThemeManager.shared.applyAll(to: self)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        refreshNotificationUI()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Notifications"
        NotificationCenter.default.addObserver(
                self,
                selector: #selector(refreshNotificationUI),
                name: UIApplication.willEnterForegroundNotification,
                object: nil
            )

            
    }
    
    @objc func refreshNotificationUI() {
        // Calendar access
        let calendarAuthStatus = EKEventStore.authorizationStatus(for: .event)
        calendarSwitch.isOn = (calendarAuthStatus == .fullAccess)

        // Notification access
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.eventSwitch.isOn = (
                    settings.authorizationStatus == .authorized
                )
            }
        }
    }
    
    @IBAction func calendarToggle(_ sender: Any) {
        guard let toggleSwitch = sender as? UISwitch else { return }

            let desiredState = toggleSwitch.isOn

            // Disable the switch to prevent multiple taps during async request
            toggleSwitch.isEnabled = false

            if desiredState {
                // Request calendar access (full or write-only)
                eventStore.requestFullAccessToEvents { granted, error in
                    DispatchQueue.main.async {
                        if granted {
                            self.calendarSwitch.isOn = true
                            self.showNotificationStatus(name: "Calendar Integration", isOn: true)
                        } else {
                            self.calendarSwitch.isOn = false
                            self.showSettingsAlert(message: "Calendar access is required to enable this feature.")
                        }
                        toggleSwitch.isEnabled = true
                    }
                }
            } else {
                // User turned switch OFF — show alert to go to Settings because app cannot revoke permissions
                self.showSettingsAlert(message: "To remove calendar access, go to Settings > Privacy > Calendars.")

                // Reset the switch to actual permission status to reflect reality
                let status = EKEventStore.authorizationStatus(for: .event)
                self.calendarSwitch.isOn = (status == .fullAccess || status == .writeOnly)

                toggleSwitch.isEnabled = true
            }
        
    }
    
    @IBAction func eventToggle(_ sender: Any) {
        guard let toggleSwitch = sender as? UISwitch else { return }

            let center = UNUserNotificationCenter.current()
            let desiredState = toggleSwitch.isOn

            // Disable the switch to prevent multiple taps during async request
            toggleSwitch.isEnabled = false

            if desiredState {
                // Request notification permission
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    DispatchQueue.main.async {
                        if granted {
                            self.eventSwitch.isOn = true
                            self.showNotificationStatus(name: "Event Notifications", isOn: true)
                        } else {
                            self.eventSwitch.isOn = false
                            self.showSettingsAlert(message: "Notifications are required to enable this feature.")
                        }
                        toggleSwitch.isEnabled = true
                    }
                }
            } else {
                // User turned switch OFF — show alert to go to Settings because app cannot revoke permissions
                self.showSettingsAlert(message: "To disable notifications completely, go to Settings > Notifications.")

                // Reset the switch to actual permission status to reflect reality
                center.getNotificationSettings { settings in
                    DispatchQueue.main.async {
                        self.eventSwitch.isOn = (settings.authorizationStatus == .authorized)
                        toggleSwitch.isEnabled = true
                    }
                }
            }
        
    }
    
    
    func showSettingsAlert(message: String) {
        let alert = UIAlertController(title: "Permission Needed", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString),
               UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(alert, animated: true)
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
