//
//  ThemeManager.swift
//  SyllaBuddy
//
//  Created by Vincent Vo on 7/24/25.
//

import Foundation
import UIKit

// MARK: - AppTheme
enum AppTheme: String, CaseIterable {
    case `default` = "Default"
    case dark = "Dark"
    case light = "Light"
    case blue = "Blue"
    case green = "Green"
    
    var primaryColor: UIColor {
        switch self {
        case .default:
            return UIColor(named: "DefaultBackground") ?? .systemBackground
        case .dark:
            return .black
        case .light:
            return .white
        case .blue:
            return UIColor.systemBlue.withAlphaComponent(0.1)
        case .green:
            return UIColor.systemGreen.withAlphaComponent(0.1)
        }
    }
    
    var textColor: UIColor {
        switch self {
        case .default, .light:
            return .label
        case .dark, .blue, .green:
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
        case .blue:
            return .systemBlue
        case .green:
            return .systemGreen
        }
    }
}

// MARK: - AppFont
enum AppFont: String, CaseIterable {
    case system = "System"
    case serif = "Times New Roman"
    case monospaced = "Courier New"
    
    func font(with originalFont: UIFont) -> UIFont {
        let size = originalFont.pointSize
        switch self {
        case .system:
            return UIFont.systemFont(ofSize: size)
        default:
            return UIFont(name: familyName, size: size) ?? UIFont.systemFont(ofSize: size)
        }
    }
    
    var familyName: String {
        switch self {
        case .system:
            return UIFont.systemFont(ofSize: 12).familyName
        case .serif:
            return "Times New Roman"
        case .monospaced:
            return "Courier New"
        }
    }
}

// MARK: - ThemeManager
class ThemeManager {
    static let shared = ThemeManager()
    private init() {}
    
    private(set) var currentTheme: AppTheme = .default
    private(set) var currentFont: AppFont = .system
    
    // MARK: - Preferences
    func loadPreferences() {
        if let themeName = UserDefaults.standard.string(forKey: "appTheme"),
           let theme = AppTheme(rawValue: themeName) {
            currentTheme = theme
        }
        if let fontName = UserDefaults.standard.string(forKey: "appFont"),
           let font = AppFont(rawValue: fontName) {
            currentFont = font
        }
    }
    
    // MARK: - Apply All
    func applyAll(to viewController: UIViewController) {
        loadPreferences()
        applyTheme(to: viewController)
        applyFont(to: viewController.view)
        refreshButtons(in: viewController.view)
        applyFontToNavigationBar(for: viewController)
        applyFontToTabBarItems()
    }
    
    // MARK: - Theme
    func applyTheme(to viewController: UIViewController) {
        viewController.view.backgroundColor = currentTheme.primaryColor
        
        if let navController = viewController.navigationController {
            navController.navigationBar.barTintColor = currentTheme.navigationBarColor
            navController.navigationBar.tintColor = currentTheme.textColor
            applyFontToNavigationBar(for: viewController)
        }
        
        updateTextColors(in: viewController.view)
    }
    
    func updateTheme(_ theme: AppTheme) {
        UserDefaults.standard.set(theme.rawValue, forKey: "appTheme")
        currentTheme = theme
    }
    
    // MARK: - Font
    func applyFont(to view: UIView) {
        for subview in view.subviews {
            if let label = subview as? UILabel, let font = label.font {
                label.font = currentFont.font(with: font)
            } else if let button = subview as? UIButton, let font = button.titleLabel?.font {
                button.titleLabel?.font = currentFont.font(with: font)
            } else if let textField = subview as? UITextField, let font = textField.font {
                textField.font = currentFont.font(with: font)
            }
            applyFont(to: subview)
        }
    }
    
    func updateFont(_ font: AppFont) {
        UserDefaults.standard.set(font.rawValue, forKey: "appFont")
        currentFont = font
    }
    
    // MARK: - Navigation Bar
    func applyFontToNavigationBar(for viewController: UIViewController) {
        guard let navBar = viewController.navigationController?.navigationBar else { return }
        navBar.titleTextAttributes = [
            .foregroundColor: currentTheme.textColor,
            .font: UIFont(name: currentFont.familyName, size: 18) ?? UIFont.systemFont(ofSize: 18)
        ]
        
        let backButtonAppearance = UIBarButtonItem.appearance()
        backButtonAppearance.setTitleTextAttributes(
            [
                .font: UIFont(name: currentFont.familyName, size: 16) ?? UIFont.systemFont(ofSize: 16),
                .foregroundColor: currentTheme.textColor
            ],
            for: .normal
        )
    }
    
    // MARK: - Tab Bar
    func applyFontToTabBarItems() {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: currentFont.familyName, size: 10) ?? UIFont.systemFont(ofSize: 10),
            .foregroundColor: currentTheme.textColor
        ]
        UITabBarItem.appearance().setTitleTextAttributes(attributes, for: .normal)
    }
    
    // MARK: - Helpers
    private func refreshButtons(in view: UIView) {
        for subview in view.subviews {
            if let button = subview as? UIButton {
                let currentSize = button.titleLabel?.font.pointSize ?? 17
                button.titleLabel?.font = UIFont(name: currentFont.familyName, size: currentSize)
                    ?? UIFont.systemFont(ofSize: currentSize)
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
