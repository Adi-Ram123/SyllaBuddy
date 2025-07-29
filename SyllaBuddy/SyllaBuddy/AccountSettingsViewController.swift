//
//  AccountSettingsViewController.swift
//  SyllaBuddy
//
//  Created by Vincent Vo on 7/15/25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class AccountSettingsViewController: UIViewController {

    @IBOutlet weak var emailLabel: UILabel!
    
    @IBOutlet weak var newPasswordTextField: UITextField!
    @IBOutlet weak var confirmPasswordTextField: UITextField!
    @IBOutlet weak var changePasswordSaveButton: UIButton!
    
    @IBOutlet weak var displayNameTextField: UITextField!
    @IBOutlet weak var displayNameSaveButton: UIButton!
    
    @IBOutlet weak var institutionTextField: UITextField!
    @IBOutlet weak var institutionSaveButton: UIButton!
    
    private let db = Firestore.firestore()
    private var userDocumentID: String?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        ThemeManager.shared.applyAll(to: self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Account Settings"
        setupInitialUI()
        loadUserData()
    }
    
    private func setupInitialUI() {
        if let email = Auth.auth().currentUser?.email {
            emailLabel.text = "Email: \(email)"
        } else {
            emailLabel.text = "Email: (unknown)"
        }
        newPasswordTextField.isSecureTextEntry = true
        confirmPasswordTextField.isSecureTextEntry = true
    }
    
    // MARK: - Change Password
    @IBAction func changePasswordTapped(_ sender: Any) {
        guard let newPassword = newPasswordTextField.text, !newPassword.isEmpty,
              let confirmPassword = confirmPasswordTextField.text, !confirmPassword.isEmpty else {
            showAlert(title: "Error", message: "Please fill out both password fields.")
            return
        }
        
        guard newPassword == confirmPassword else {
            showAlert(title: "Error", message: "Passwords do not match.")
            return
        }
        
        guard let user = Auth.auth().currentUser else { return }
        user.updatePassword(to: newPassword) { error in
            if let error = error {
                self.showAlert(title: "Error", message: "Failed to update password: \(error.localizedDescription)")
            } else {
                self.newPasswordTextField.text = ""
                self.confirmPasswordTextField.text = ""
                self.showAlert(title: "Success", message: "Password updated successfully.")
            }
        }
    }
    
    // MARK: - Change Display Name
    @IBAction func saveDisplayNameTapped(_ sender: Any) {
        guard let newName = displayNameTextField.text, !newName.isEmpty else {
            showAlert(title: "Error", message: "Display name cannot be empty.")
            return
        }
        guard let docID = userDocumentID else { return }
        
        db.collection("User").document(docID).updateData(["Username": newName]) { error in
            if let error = error {
                self.showAlert(title: "Error", message: "Failed to update display name: \(error.localizedDescription)")
            } else {
                self.showAlert(title: "Success", message: "Display name updated.")
            }
        }
    }
    
    // MARK: - Change Institution
    @IBAction func saveInstitutionTapped(_ sender: Any) {
        guard let institution = institutionTextField.text, !institution.isEmpty else {
            showAlert(title: "Error", message: "Institution cannot be empty.")
            return
        }
        guard let docID = userDocumentID else { return }
        
        db.collection("User").document(docID).updateData(["University": institution]) { error in
            if let error = error {
                self.showAlert(title: "Error", message: "Failed to update institution: \(error.localizedDescription)")
            } else {
                self.showAlert(title: "Success", message: "Institution updated.")
            }
        }
    }
    
    private func loadUserData() {
        guard let userEmail = Auth.auth().currentUser?.email else { return }
        
        let collection = db.collection("User")
        collection.whereField("Email", isEqualTo: userEmail).getDocuments { querySnapshot, error in
            if let error = error {
                print("Error querying user: \(error.localizedDescription)")
            } else if let documents = querySnapshot?.documents, let userDoc = documents.first {
                self.userDocumentID = userDoc.documentID
                let data = userDoc.data()
                
                self.displayNameTextField.text = data["Username"] as? String
                self.institutionTextField.text = data["University"] as? String
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
