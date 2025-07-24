//
//  ThemeManager.swift
//  SyllaBuddy
//
//  Created by Vincent Vo on 7/24/25.
//

import Foundation
import UIKit

enum AppTheme: String, CaseIterable {
    case `default` = "Default"
    case dark = "Dark"
    case light = "Light"
    case blue = "Blue"
    case green = "Green"
    
    var primaryColor: UIColor {
        switch self {
        case .default:
            return .systemBackground
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
        case .default, .light, .blue, .green:
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
        case .blue:
            return .systemBlue
        case .green:
            return .systemGreen
        }
    }
}

enum AppFont: String, CaseIterable {
    case system = "System"
    case serif = "Times New Roman"
    case monospaced = "Courier New"
    
    func font(ofSize size: CGFloat) -> UIFont {
        switch self {
        case .system:
            return UIFont.systemFont(ofSize: size)
        case .serif:
            return UIFont(name: "Times New Roman", size: size) ?? UIFont.systemFont(ofSize: size)
        case .monospaced:
            return UIFont(name: "Courier New", size: size) ?? UIFont.systemFont(ofSize: size)
        }
    }
}

class ThemeManager {
    static let shared = ThemeManager()
    
    private init() {}
    
    private(set) var currentTheme: AppTheme = .default
    private(set) var currentFont: AppFont = .system
    
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
    
    func applyGlobalAppearance() {
        loadPreferences()
        let navAppearance = UINavigationBar.appearance()
        navAppearance.barTintColor = currentTheme.navigationBarColor
        navAppearance.titleTextAttributes = [
            .foregroundColor: currentTheme.textColor,
            .font: currentFont.font(ofSize: 18)
        ]
        navAppearance.tintColor = currentTheme.textColor
        
        let tabAppearance = UITabBar.appearance()
        tabAppearance.barTintColor = currentTheme.navigationBarColor
        tabAppearance.tintColor = currentTheme.textColor
        
        if let window = UIApplication.shared.windows.first {
            window.backgroundColor = currentTheme.primaryColor
        }
    }
    
    func applyTheme(to viewController: UIViewController) {
        viewController.view.backgroundColor = currentTheme.primaryColor
        viewController.view.tintColor = currentTheme.textColor
    }
    
    func updateTheme(_ theme: AppTheme) {
        UserDefaults.standard.set(theme.rawValue, forKey: "appTheme")
        currentTheme = theme
        applyGlobalAppearance()
    }
    
    func updateFont(_ font: AppFont) {
        UserDefaults.standard.set(font.rawValue, forKey: "appFont")
        currentFont = font
        applyGlobalAppearance()
    }
}
