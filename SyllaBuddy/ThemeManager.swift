//
//  ThemeManager.swift
//  SyllaBuddy
//
//  Created by Vincent Vo on 7/24/25.
//

import Foundation
import UIKit
import FirebaseAuth
import FirebaseFirestore

// MARK: - AppTheme
enum AppTheme: String, CaseIterable {
    case `default` = "Default"
    case dark = "Dark"
    case light = "Light"
    
    var primaryColor: UIColor {
        switch self {
        case .default:
            return UIColor(named: "DefaultBackground") ?? .systemBackground
        case .dark:
            return .black
        case .light:
            return .white
        }
    }
    
    var textColor: UIColor {
        switch self {
        case .default, .light:
            return .label
        case .dark:
            return .white
        }
    }
    
    var navigationBarColor: UIColor {
        switch self {
        case .default:
            return .systemBackground
        case .dark:
            return .black
        case .light:
            return .white
        }
    }
}

// MARK: - AppFont
enum AppFont: String, CaseIterable {
    case system = "System"
    case serif = "Times New Roman"
    case monospaced = "Courier New"
    
    func font(ofSize size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        switch self {
        case .system:
            return UIFont.systemFont(ofSize: size, weight: weight)
        case .serif:
            return UIFont(name: "Times New Roman", size: size) ?? UIFont.systemFont(ofSize: size, weight: weight)
        case .monospaced:
            return UIFont(name: "Courier New", size: size) ?? UIFont.systemFont(ofSize: size, weight: weight)
        }
    }
}

// MARK: - ThemeManager
class ThemeManager {
    static let shared = ThemeManager()
    private init() {}
    
    private let db = Firestore.firestore()
    
    private(set) var currentTheme: AppTheme = .default
    private(set) var currentFont: AppFont = .system
    
    // MARK: - Preferences
    func loadPreferences(completion: (() -> Void)? = nil) {
        guard let user = Auth.auth().currentUser else {
            loadFromLocal()
            completion?()
            return
        }
        
        // Fetch user-specific settings from Firestore
        db.collection("User").whereField("Email", isEqualTo: user.email ?? "").getDocuments { snapshot, error in
            if let error = error {
                print("Error loading settings: \(error.localizedDescription)")
                self.loadFromLocal()
                completion?()
                return
            }
            
            if let doc = snapshot?.documents.first {
                let data = doc.data()
                
                if let themeName = data["theme"] as? String, let theme = AppTheme(rawValue: themeName) {
                    self.currentTheme = theme
                    UserDefaults.standard.set(themeName, forKey: "appTheme")
                }
                
                if let fontName = data["font"] as? String, let font = AppFont(rawValue: fontName) {
                    self.currentFont = font
                    UserDefaults.standard.set(fontName, forKey: "appFont")
                }
            } else {
                self.loadFromLocal()
            }
            completion?()
        }
    }
    
    private func loadFromLocal() {
        if let themeName = UserDefaults.standard.string(forKey: "appTheme"),
           let theme = AppTheme(rawValue: themeName) {
            currentTheme = theme
        }
        if let fontName = UserDefaults.standard.string(forKey: "appFont"),
           let font = AppFont(rawValue: fontName) {
            currentFont = font
        }
    }
    
    private func savePreferences() {
        guard let user = Auth.auth().currentUser else { return }
        
        db.collection("User").whereField("Email", isEqualTo: user.email ?? "")
            .getDocuments { snapshot, error in
                if let doc = snapshot?.documents.first {
                    self.db.collection("User").document(doc.documentID).updateData([
                        "theme": self.currentTheme.rawValue,
                        "font": self.currentFont.rawValue
                    ]) { error in
                        if let error = error {
                            print("Error saving settings: \(error.localizedDescription)")
                        } else {
                            print("User settings saved to Firestore.")
                        }
                    }
                }
            }
    }
    
    // MARK: - Apply All
    func applyAll(to viewController: UIViewController, reloadFromServer: Bool = true) {
        if reloadFromServer {
            loadPreferences {
                DispatchQueue.main.async {
                    self.applyAll(to: viewController, reloadFromServer: false)
                }
            }
        } else {
            applyTheme(to: viewController)
            applyFont(to: viewController.view)
            refreshButtons(in: viewController.view)
            applyFontToNavigationBar(for: viewController)
            applyFontToTabBarItems()
        }
    }
    
    // MARK: - Theme
    func applyTheme(to viewController: UIViewController) {
        viewController.view.backgroundColor = currentTheme.primaryColor
        if let nav = viewController.navigationController {
            nav.navigationBar.barTintColor = currentTheme.navigationBarColor
            nav.navigationBar.tintColor = currentTheme.textColor
            applyFontToNavigationBar(for: viewController)
        }
        updateTextColors(in: viewController.view)
    }
    
    func updateTheme(_ theme: AppTheme) {
        currentTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: "appTheme")
        savePreferences()
        NotificationCenter.default.post(name: NSNotification.Name("ThemeChanged"), object: nil)
    }
    
    // MARK: - Font
    func applyFont(to view: UIView) {
        for subview in view.subviews {
            if let label = subview as? UILabel {
                label.font = currentFont.font(ofSize: label.font.pointSize)
            } else if let button = subview as? UIButton, let font = button.titleLabel?.font {
                button.titleLabel?.font = currentFont.font(ofSize: font.pointSize)
            } else if let textField = subview as? UITextField, let font = textField.font {
                textField.font = currentFont.font(ofSize: font.pointSize)
            }
            applyFont(to: subview)
        }
    }
    
    func updateFont(_ font: AppFont) {
        currentFont = font
        UserDefaults.standard.set(font.rawValue, forKey: "appFont")
        savePreferences()
        NotificationCenter.default.post(name: NSNotification.Name("FontChanged"), object: nil)
    }
    
    // MARK: - Navigation Bar
    func applyFontToNavigationBar(for viewController: UIViewController) {
        guard let navBar = viewController.navigationController?.navigationBar else { return }
        navBar.titleTextAttributes = [
            .foregroundColor: currentTheme.textColor,
            .font: currentFont.font(ofSize: 18, weight: .semibold)
        ]
        
        let backFont = currentFont.font(ofSize: 16)
        UIBarButtonItem.appearance().setTitleTextAttributes(
            [.font: backFont, .foregroundColor: currentTheme.textColor],
            for: .normal
        )
    }
    
    // MARK: - Tab Bar
    func applyFontToTabBarItems() {
        let tabFont = currentFont.font(ofSize: 10)
        UITabBarItem.appearance().setTitleTextAttributes([.font: tabFont, .foregroundColor: currentTheme.textColor], for: .normal)
    }
    
    // MARK: - Helpers
    private func refreshButtons(in view: UIView) {
        for subview in view.subviews {
            if let button = subview as? UIButton, let font = button.titleLabel?.font {
                button.titleLabel?.font = currentFont.font(ofSize: font.pointSize)
            }
            refreshButtons(in: subview)
        }
    }
    
    private func updateTextColors(in view: UIView) {
        for subview in view.subviews {
            if let label = subview as? UILabel {
                label.textColor = currentTheme.textColor
            } else if let button = subview as? UIButton {
                button.setTitleColor(currentTheme.textColor, for: .normal)
            }
            updateTextColors(in: subview)
        }
    }
}
