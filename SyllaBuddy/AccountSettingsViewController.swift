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
    @IBOutlet weak var passwordLabel: UILabel!
    
    @IBOutlet weak var revealEmailButton: UIButton!
    @IBOutlet weak var revealPasswordButton: UIButton!
    
    @IBOutlet weak var displayNameTextField: UITextField!
    @IBOutlet weak var displayNameSaveButton: UIButton!
    
    @IBOutlet weak var institutionTextField: UITextField!
    @IBOutlet weak var institutionSaveButton: UIButton!
    
    private var emailHidden: Bool = true
    private var passwordHidden: Bool = true
    private let db = Firestore.firestore()
    
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
        emailLabel.text = "Email"
        passwordLabel.text = "Password"
        revealEmailButton.setTitle("Tap to Reveal", for: .normal)
        revealPasswordButton.setTitle("Tap to Reveal", for: .normal)
    }
    
    @IBAction func revealEmailTapped(_ sender: UIButton) {
        emailHidden.toggle()
        if let email = Auth.auth().currentUser?.email {
            revealEmailButton.setTitle(emailHidden ? "Tap to Reveal" : email, for: .normal)
        }
    }
    
    @IBAction func revealPasswordTapped(_ sender: UIButton) {
        passwordHidden.toggle()
        revealPasswordButton.setTitle(passwordHidden ? "Tap to Reveal" : "********", for: .normal)
    }
    
    @IBAction func saveDisplayNameTapped(_ sender: Any) {
        guard let newName = displayNameTextField.text, !newName.isEmpty else {
            showAlert(title: "Error", message: "Display name cannot be empty.")
            return
        }
        guard let user = Auth.auth().currentUser else { return }
        
        db.collection("users").document(user.uid).setData(["username": newName], merge: true) { error in
            if let error = error {
                self.showAlert(title: "Error", message: "Failed to update display name: \(error.localizedDescription)")
            } else {
                self.showAlert(title: "Success", message: "Display name updated.")
            }
        }
    }
    
    @IBAction func saveInstitutionTapped(_ sender: Any) {
        guard let institution = institutionTextField.text, !institution.isEmpty else {
            showAlert(title: "Error", message: "Institution cannot be empty.")
            return
        }
        guard let user = Auth.auth().currentUser else { return }
        
        db.collection("users").document(user.uid).setData(["university": institution], merge: true) { error in
            if let error = error {
                self.showAlert(title: "Error", message: "Failed to update institution: \(error.localizedDescription)")
            } else {
                self.showAlert(title: "Success", message: "Institution updated.")
            }
        }
    }
    
    private func loadUserData() {
        let userEmail = Auth.auth().currentUser!.email
        print(userEmail!)
        
        let collection = db.collection("User")
        
        collection.whereField("Email", isEqualTo: userEmail!).getDocuments
        {
            (querySnapshot, error) in
            if let error = error {
                print("Error querying user: \(error.localizedDescription)")
            } else if let documents = querySnapshot?.documents, !documents.isEmpty {
                let userDoc = documents[0]
                let data = userDoc.data()
                
                let uni = data["University"] as! String
                let user = data["Username"] as! String
                
                self.displayNameTextField.text = user
                self.institutionTextField.text = uni
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
