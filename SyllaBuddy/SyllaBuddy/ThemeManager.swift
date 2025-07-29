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
    case light = "Light"
    
    var primaryColor: UIColor {
        switch self {
        case .default:
            return UIColor(named: "DefaultBackground") ?? .systemBackground
        case .light:
            return .white
        }
    }
    
    var textColor: UIColor {
        switch self {
        case .default, .light:
            return .label
        }
    }
    
    var navigationBarColor: UIColor {
        switch self {
        case .default:
            return UIColor(named: "DefaultBackground") ?? .systemBackground
        case .light:
            return .white
        }
    }
}

// MARK: - AppFont
enum AppFont: String, CaseIterable {
    case system = "System"
    case serif = "Times New Roman"
    
    func font(ofSize size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        switch self {
        case .system:
            return UIFont.systemFont(ofSize: size, weight: weight)
        case .serif:
            return UIFont(name: "Times New Roman", size: size) ?? UIFont.systemFont(ofSize: size, weight: weight)
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
            // Apply theme and font to the main view
            applyTheme(to: viewController)
            applyFont(to: viewController.view)
            refreshButtons(in: viewController.view)
            applyFontAndThemeToTableCells(in: viewController.view)
            applyThemetoTables(in: viewController.view)
            applyThemeToToolbars(in: viewController.view)
            
            // Always update navigation bar styles (title font & color)
            if let navController = viewController.navigationController {
                applyFontToNavigationBar(for: viewController)
                navController.navigationBar.layoutIfNeeded()
            }
        }
    }

    // MARK: - Theme
    func applyTheme(to viewController: UIViewController) {
        viewController.view.backgroundColor = currentTheme.primaryColor
        if let nav = viewController.navigationController {
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
                label.textColor = currentTheme.textColor

            } else if let button = subview as? UIButton {
                if let font = button.titleLabel?.font {
                    button.titleLabel?.font = currentFont.font(ofSize: font.pointSize)
                }
                button.setTitleColor(currentTheme.textColor, for: .normal)
                button.setTitleColor(currentTheme.textColor.withAlphaComponent(0.7), for: .highlighted)
                
            } else if let textField = subview as? UITextField {
                if let font = textField.font {
                    textField.font = currentFont.font(ofSize: font.pointSize)
                }
                textField.textColor = currentTheme.textColor

            } else if let textView = subview as? UITextView {
                if let font = textView.font {
                    textView.font = currentFont.font(ofSize: font.pointSize)
                }
                textView.textColor = currentTheme.textColor
            }

            // Recursively apply to subviews
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
        
        let textColor = currentTheme.textColor
        let titleFont = currentFont.font(ofSize: 18, weight: .semibold)
        let largeTitleFont = currentFont.font(ofSize: 32, weight: .bold)
        
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = currentTheme.navigationBarColor
        appearance.titleTextAttributes = [
            .foregroundColor: textColor,
            .font: titleFont
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: textColor,
            .font: largeTitleFont
        ]
        
        navBar.standardAppearance = appearance
        navBar.scrollEdgeAppearance = appearance
        navBar.compactAppearance = appearance
        navBar.compactScrollEdgeAppearance = appearance
        navBar.tintColor = textColor
        
        // Force layout update
        navBar.layoutIfNeeded()
    }

    
    // MARK: - Toolbar
    private func applyThemeToToolbars(in view: UIView) {
        for subview in view.subviews {
            if let toolbar = subview as? UIToolbar {
                toolbar.barTintColor = currentTheme.navigationBarColor
                toolbar.tintColor = currentTheme.textColor
                
                // Update bar button items with custom views
                for item in toolbar.items ?? [] {
                    if let customView = item.customView {
                        applyFont(to: customView)  // Apply font to custom buttons/labels
                    }
                }
            }
            applyThemeToToolbars(in: subview) // Recursive for nested views
        }
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
    
    // MARK: - Table Cell Font & Theme Updates
    func applyFontAndThemeToTableCells(in view: UIView) {
        for subview in view.subviews {
            if let tableView = subview as? UITableView {
                for cell in tableView.visibleCells {
                    updateTableCellAppearance(cell)
                }
            }
            applyFontAndThemeToTableCells(in: subview)
        }
    }

    private func updateTableCellAppearance(_ cell: UITableViewCell) {
        // Update text label fonts
        if let textLabel = cell.textLabel, let font = textLabel.font {
            textLabel.font = currentFont.font(ofSize: font.pointSize)
            textLabel.textColor = currentTheme.textColor
        }
        
        if let detailTextLabel = cell.detailTextLabel, let font = detailTextLabel.font {
            detailTextLabel.font = currentFont.font(ofSize: font.pointSize)
            detailTextLabel.textColor = currentTheme.textColor
        }
        cell.backgroundColor = currentTheme.primaryColor
    }
    
    private func applyThemetoTables(in view: UIView) {
        for subview in view.subviews {
            if let tableView = subview as? UITableView {
                tableView.backgroundColor = currentTheme.primaryColor
            }
            applyThemetoTables(in: subview)
        }
    }
}
