//
//  AppSettingsViewController.swift
//  SyllaBuddy
//
//  Created by Vincent Vo on 7/15/25.
//

import UIKit
import FirebaseAuth

class AppSettingsViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource, UITextFieldDelegate {

    @IBOutlet weak var themeTextField: UITextField!
    @IBOutlet weak var fontTextField: UITextField!
    @IBOutlet weak var logoutButton: UIButton!
    
    @IBOutlet weak var themeSaveButton: UIButton!      // Save Theme Button
    @IBOutlet weak var fontSaveButton: UIButton!       // Save Font Button
    
    private let themes = AppTheme.allCases.map { $0.rawValue }
    private let fonts = AppFont.allCases.map { $0.rawValue }
    private var selectedTheme: String = AppTheme.default.rawValue
    private var selectedFont: String = AppFont.system.rawValue
    
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
    }
    
    // MARK: - Picker Setup
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
    }
    
    // MARK: - PickerView DataSource/Delegate
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
    
    @IBAction func saveThemeTapped(_ sender: Any) {
        if let theme = AppTheme(rawValue: selectedTheme) {
            ThemeManager.shared.updateTheme(theme)
            ThemeManager.shared.applyTheme(to: self)  // Apply theme colors
            ThemeManager.shared.applyFont(to: self.view) // Reapply font
            ThemeManager.shared.applyFontToNavigationBar(for: self)
            ThemeManager.shared.applyFontToTabBarItems()
        }
        showAlert(title: "Theme Saved", message: "App theme has been updated.")
    }

    @IBAction func saveFontTapped(_ sender: Any) {
        if let font = AppFont(rawValue: selectedFont) {
            ThemeManager.shared.updateFont(font)
            ThemeManager.shared.applyFont(to: self.view)  // Reapply font
            ThemeManager.shared.applyFontToNavigationBar(for: self)
            ThemeManager.shared.applyFontToTabBarItems()
        }
        showAlert(title: "Font Saved", message: "Font style has been updated.")
    }
    
    // MARK: - Load Preferences
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

    // MARK: - Logout
    @IBAction func logoutTapped(_ sender: Any) {
        do {
            try Auth.auth().signOut()
            navigationController?.popToRootViewController(animated: true)
            NotificationScheduler.clearNotifiedEvents()
        } catch {
            print("Error logging out: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Alert
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
