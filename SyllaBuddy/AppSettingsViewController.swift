//
//  AppSettingsViewController.swift
//  SyllaBuddy
//
//  Created by Vincent Vo on 7/15/25.
//

import UIKit
import FirebaseAuth
import EventKit

class AppSettingsViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource, UITextFieldDelegate {

    @IBOutlet weak var themeTextField: UITextField!
    @IBOutlet weak var themeSaveButton: UIButton!
    @IBOutlet weak var fontTextField: UITextField!
    @IBOutlet weak var fontSaveButton: UIButton!
    @IBOutlet weak var linkCalendarButton: UIButton!
    @IBOutlet weak var logoutButton: UIButton!
    
    private let themes = ["Default", "Dark", "Light", "Blue", "Green"]
    private let fonts = ["System", "Times New Roman", "Courier New"]
    private var selectedTheme: String = "Default"
    private var selectedFont: String = "System"
    
    private var themePicker = UIPickerView()
    private var fontPicker = UIPickerView()
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        ThemeManager.shared.applyAll(to: self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "App Settings"
        
        setupPickers()
        loadSavedPreferences()
        // Do any additional setup after loading the view.
    }
    
    private func setupPickers() {
        themePicker.delegate = self
        themePicker.dataSource = self
        themePicker.tag = 1
        themeTextField.inputView = themePicker
        themeTextField.delegate = self
        
        fontPicker.delegate = self
        fontPicker.dataSource = self
        fontPicker.tag = 2
        fontTextField.inputView = fontPicker
        fontTextField.delegate = self
        
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let doneButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(doneTapped))
        toolbar.setItems([doneButton], animated: false)
        themeTextField.inputAccessoryView = toolbar
        fontTextField.inputAccessoryView = toolbar
    }
    
    @objc private func doneTapped() {
        view.endEditing(true)
        ThemeManager.shared.applyTheme(to: self)
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return pickerView.tag == 1 ? themes.count : fonts.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return pickerView.tag == 1 ? themes[row] : fonts[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if pickerView.tag == 1 {
            selectedTheme = themes[row]
            themeTextField.text = selectedTheme
        } else {
            selectedFont = fonts[row]
            fontTextField.text = selectedFont
        }
    }
    
    private func loadSavedPreferences() {
        if let savedTheme = UserDefaults.standard.string(forKey: "appTheme") {
            selectedTheme = savedTheme
            themeTextField.text = savedTheme
            if let index = themes.firstIndex(of: savedTheme) {
                themePicker.selectRow(index, inComponent: 0, animated: false)
            }
        }
        if let savedFont = UserDefaults.standard.string(forKey: "appFont") {
            selectedFont = savedFont
            fontTextField.text = savedFont
            if let index = fonts.firstIndex(of: savedFont) {
                fontPicker.selectRow(index, inComponent: 0, animated: false)
            }
        }
    }
    
    @IBAction func saveThemeTapped(_ sender: Any) {
        if let theme = AppTheme(rawValue: selectedTheme) {
            // Save theme and update ThemeManager
            ThemeManager.shared.updateTheme(theme)
            // Apply the theme to the current screen only
            ThemeManager.shared.applyTheme(to: self)
        }
        showAlert(title: "Theme Saved", message: "App theme has been updated.")
    }
    
    @IBAction func saveFontTapped(_ sender: Any) {
        if let font = AppFont(rawValue: selectedFont) {
            ThemeManager.shared.updateFont(font)
            
            // Apply font immediately
            ThemeManager.shared.applyFont(to: self.view)
        }
        showAlert(title: "Font Saved", message: "Font style has been updated.")
    }


    @IBAction func linkToCalendarTapped(_ sender: Any) {
        let eventStore = EKEventStore()

        // Request access to the Calendar
        eventStore.requestAccess(to: .event) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.showAlert(title: "Error", message: "Failed to access calendar: \(error.localizedDescription)")
                    return
                }
                
                if granted {
                    // placeholder
                    let event = EKEvent(eventStore: eventStore)
                    event.title = "SyllaBuddy Event"
                    event.startDate = Date().addingTimeInterval(3600)
                    event.endDate = Date().addingTimeInterval(7200)
                    event.calendar = eventStore.defaultCalendarForNewEvents

                    do {
                        try eventStore.save(event, span: .thisEvent)
                        self.showAlert(title: "Success", message: "Event added to your calendar.")
                    } catch {
                        self.showAlert(title: "Error", message: "Could not save event: \(error.localizedDescription)")
                    }
                } else {
                    self.showAlert(title: "Permission Denied", message: "Calendar access is required to link events.")
                }
            }
        }
    }

    @IBAction func logoutTapped(_ sender: Any) {
        do {
            try Auth.auth().signOut()
            navigationController?.popToRootViewController(animated: true)
            NotificationScheduler.clearNotifiedEvents()
        } catch {
            print("Error logging out: \(error.localizedDescription)")
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            // Re-apply font after alert dismisses
            ThemeManager.shared.applyFont(to: self.view)
        }))
        present(alert, animated: true)
    }
}
