//
//  CreateAccountView.swift
//  SyllaBuddy
//
//  Created by Aditya Ramaswamy on 7/10/25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class CreateAccountView: UIViewController, UITextFieldDelegate {
    
    @IBOutlet weak var user: UITextField!
    @IBOutlet weak var email: UITextField!
    @IBOutlet weak var password: UITextField!
    @IBOutlet weak var confirm: UITextField!
    @IBOutlet weak var uni: UITextField!
    let db = Firestore.firestore()
    let createId = "createSegue"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        user.delegate = self
        email.delegate = self
        password.delegate = self
        confirm.delegate = self
        uni.delegate = self
        password.isSecureTextEntry = true
        confirm.isSecureTextEntry = true

        // Do any additional setup after loading the view.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        user.text = ""
        uni.text = ""
        email.text = ""
        password.text = ""
        confirm.text = ""
        ThemeManager.shared.applyAll(to: self)
    }
    
    @IBAction func accountCreation(_ sender: Any) {
        
        guard let user = user.text, !user.isEmpty else {
            makePopup(popupTitle: "Account Creation Error", popupMessage: "Username was not filled out")
            return
        }
        
        guard let college = uni.text, !college.isEmpty else {
            makePopup(popupTitle: "Account Creation Error", popupMessage: "University was not filled out")
            return
        }
        
        guard let mail = email.text, !mail.isEmpty else {
            makePopup(popupTitle: "Account Creation Error", popupMessage: "Email was not filled out")
            return
        }
        
        guard let pass = password.text, !pass.isEmpty else {
            makePopup(popupTitle: "Account Creation Error", popupMessage: "Password was not filled out")
            return
        }
        
        guard let conf = confirm.text, pass == conf else {
            makePopup(popupTitle: "Account Creation Error", popupMessage: "Passwords do not match")
            return
        }
        
        Auth.auth().createUser(withEmail: mail, password: pass) {
            (authResult, error) in
            if let error = error as NSError? {
                let message = "\(error.localizedDescription)"
                self.makePopup(popupTitle: "Account Creation Error", popupMessage: message)
            } else {
                Auth.auth().signIn(withEmail: mail, password: pass)
                //Update user database
                let userData: [String: Any] = [
                    "Classes": [String](),
                    "Email": mail,
                    "Events": [],
                    "University": college,
                    "Username": user
                ]
                self.db.collection("User").addDocument(data: userData) {
                    (err) in
                    if let err = err {
                        print("Error updating user database:  \(err)")
                    }
                }
                self.performSegue(withIdentifier: self.createId, sender: self)
            }
        }
    }
    
    func makePopup(popupTitle:String, popupMessage:String) {
        
        let controller = UIAlertController(
            title: popupTitle,
            message: popupMessage,
            preferredStyle: .alert)
        
        controller.addAction(UIAlertAction(title: "OK", style: .default))
        
        present(controller,animated:true)
    }
    
    func textFieldShouldReturn(_ textField:UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
        
    // Called when the user clicks on the view outside of the UITextField

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
    
}
