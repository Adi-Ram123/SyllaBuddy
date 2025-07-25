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
    @IBOutlet weak var themeSaveButton: UIButton!
    @IBOutlet weak var fontTextField: UITextField!
    @IBOutlet weak var fontSaveButton: UIButton!
    @IBOutlet weak var linkCalendarButton: UIButton!
    @IBOutlet weak var logoutButton: UIButton!
    
    private let themes = ["Default", "Dark", "Light", "Blue", "Green"]
    private let fonts = ["System", "Serif", "Monospaced"]
    private var selectedTheme: String = "Default"
    private var selectedFont: String = "System"
    
    private var themePicker = UIPickerView()
    private var fontPicker = UIPickerView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "App Settings"
        
        setupPickers()
        loadSavedPreferences()
        NotificationCenter.default.addObserver(self, selector: #selector(updateTheme), name: Notification.Name("ThemeChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateFont), name: Notification.Name("FontChanged"), object: nil)
        // Do any additional setup after loading the view.
    }
    
    @objc func updateTheme() {
        ThemeManager.shared.applyTheme(to: self)
    }
    
    @objc func updateFont() {
        ThemeManager.shared.applyFont(to: self.view)
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
            ThemeManager.shared.updateTheme(theme)
            ThemeManager.shared.applyTheme(to: self)
            if let window = UIApplication.shared.windows.first {
                ThemeManager.shared.applyTheme(to: window.rootViewController!)
            }
        }
        showAlert(title: "Theme Saved", message: "App theme has been updated.")
    }
    
    @IBAction func saveFontTapped(_ sender: Any) {
        if let font = AppFont(rawValue: selectedFont) {
            ThemeManager.shared.updateFont(font)
            ThemeManager.shared.applyFont(to: self.view.window ?? self.view)
        }
        showAlert(title: "Font Saved", message: "Font style has been updated.")
    }
    
    @IBAction func linkToCalendarTapped(_ sender: Any) {
        
    }
    
    @IBAction func logoutTapped(_ sender: Any) {
        do {
            try Auth.auth().signOut()
            navigationController?.popToRootViewController(animated: true)
        } catch {
            print("Error logging out: \(error.localizedDescription)")
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated:true)
    }
}
