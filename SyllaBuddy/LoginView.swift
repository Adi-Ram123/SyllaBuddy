//
//  LoginView.swift
//  SyllaBuddy
//
//  Created by Aditya Ramaswamy on 7/10/25.
//

import UIKit
import FirebaseAuth

class LoginView: UIViewController, UITextFieldDelegate {

    
    @IBOutlet weak var email: UITextField!
    @IBOutlet weak var password: UITextField!
    let loginId = "loginSegue"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        email.delegate = self
        password.delegate = self
        password.isSecureTextEntry = true
        if let user = Auth.auth().currentUser {
            // User is signed in
            print("User is signed in with email: \(user.email ?? "No Email")")
        } else {
            // No user is signed in
            print("No user is currently signed in.")
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.email.text = ""
        self.password.text = ""
        ThemeManager.shared.applyAll(to: self)
    }
    
    @IBAction func loginPressed(_ sender: Any) {
        
        guard let mail = email.text, !mail.isEmpty else {
            makePopup(popupTitle: "Login Error", popupMessage: "Email is not filled out")
            return
        }
        
        guard let pass = password.text, !pass.isEmpty else {
            makePopup(popupTitle: "Login Error", popupMessage: "Password is not filled out")
            return
        }
        
        Auth.auth().signIn(withEmail: mail, password: pass) {
            (authResult, error) in
            if let error = error as NSError? {
                var message = "\(error.localizedDescription)"
                if(message.contains("malformed")) {
                    message = "Incorrect username or password"
                }
                print(message)
                self.makePopup(popupTitle: "Login Error", popupMessage: message)
            } else {
                print("Succesful login with email: \(mail)")
                self.performSegue(withIdentifier: self.loginId, sender: self)
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
