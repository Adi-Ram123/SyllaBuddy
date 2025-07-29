//
//  CreateThreadController.swift
//  SyllaBuddy
//
//  Created by Aditya Ramaswamy on 7/26/25.
//

import UIKit
import FirebaseFirestore
import FirebaseAuth

class CreateThreadController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
    
    let stackView = UIStackView()
    let titleLabel = UILabel()
    let messageInput = UITextView()
    let postButton = UIButton(type: .system)
    var userClasses: [String]!
    let classPickerField = UITextField()
    let classPickerView = UIPickerView()
    let titleInput = UITextField()
    let db = Firestore.firestore()

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        ThemeManager.shared.applyAll(to: self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupStackView()
        setupSubviews()

        // Do any additional setup after loading the view.
    }
    
    func setupStackView() {
        stackView.axis = .vertical
        stackView.spacing = 30
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 50),
            stackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -50)
        ])
    }
    
    func setupSubviews() {
        //Title
        titleLabel.text = "Title"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 20)
        titleLabel.textAlignment = .left
        let titleContainer = UIStackView()
        titleContainer.axis = .vertical
        titleContainer.spacing = 5
        titleContainer.alignment = .fill
        titleContainer.distribution = .fill
        titleContainer.translatesAutoresizingMaskIntoConstraints = false
        titleContainer.addArrangedSubview(titleLabel)

        //Title text field
        titleInput.placeholder = "Enter thread title"
        titleInput.borderStyle = .roundedRect
        titleInput.font = UIFont.systemFont(ofSize: 16)
        titleInput.translatesAutoresizingMaskIntoConstraints = false
        
        // Add light gray border
        titleInput.layer.borderColor = UIColor.systemGray.cgColor
        titleInput.layer.borderWidth = 1
        titleInput.layer.cornerRadius = 8
        titleInput.layer.masksToBounds = true
        titleContainer.addArrangedSubview(titleInput)
        
        // Messing with height of title
        titleInput.heightAnchor.constraint(equalToConstant: 50).isActive = true
        stackView.addArrangedSubview(titleContainer)

        // Picker Field
        classPickerField.placeholder = "Choose a class"
        classPickerField.borderStyle = .roundedRect
        classPickerField.font = UIFont.systemFont(ofSize: 16)
        classPickerField.translatesAutoresizingMaskIntoConstraints = false

        // Add light gray border
        classPickerField.layer.borderColor = UIColor.systemGray.cgColor
        classPickerField.layer.borderWidth = 1
        classPickerField.layer.cornerRadius = 8
        classPickerField.layer.masksToBounds = true

        // Add down arrow icon on right
        let arrow = UIImage(systemName: "chevron.down")
        let arrowImage = UIImageView(image: arrow)
        arrowImage.tintColor = .gray
        arrowImage.contentMode = .scaleAspectFit
        arrowImage.frame = CGRect(x: 0, y: 0, width: 10, height: 10)
        classPickerField.rightView = arrowImage
        classPickerField.rightViewMode = .always
        stackView.addArrangedSubview(classPickerField)

        //Tap gesture to allow picker to populate
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(showClassMenu))
        classPickerField.addGestureRecognizer(tapGesture)
        classPickerField.tintColor = .clear
        classPickerField.inputView = UIView()

        // Setup pickerView
        classPickerView.delegate = self
        classPickerView.dataSource = self
        classPickerField.inputView = classPickerView

        // Text View for Message
        messageInput.font = UIFont.systemFont(ofSize: 16)
        messageInput.layer.borderColor = UIColor.gray.cgColor
        messageInput.layer.borderWidth = 1
        messageInput.layer.cornerRadius = 8
        messageInput.isScrollEnabled = true
        messageInput.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(messageInput)
        
        // Messing with height of message
        messageInput.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.25).isActive = true

        // Post Button
        let buttonContainer = UIView()
        buttonContainer.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.heightAnchor.constraint(equalToConstant: 44).isActive = true
        postButton.setTitle("Post", for: .normal)
        postButton.backgroundColor = .systemBlue
        postButton.setTitleColor(.white, for: .normal)
        postButton.layer.cornerRadius = 8
        postButton.translatesAutoresizingMaskIntoConstraints = false
        postButton.addTarget(self, action: #selector(postPressed), for: .touchUpInside)

        buttonContainer.addSubview(postButton)

        NSLayoutConstraint.activate([
            postButton.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor, constant: -10),
            postButton.widthAnchor.constraint(equalTo: buttonContainer.widthAnchor, multiplier: 0.25),
            postButton.heightAnchor.constraint(equalTo: buttonContainer.heightAnchor),
            postButton.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor)
        ])
        stackView.addArrangedSubview(buttonContainer)
    }

    // Populate picker with classes
    @objc func showClassMenu() {
        let alert = UIAlertController(title: "Choose Class", message: nil, preferredStyle: .actionSheet)
        for className in userClasses {
            alert.addAction(UIAlertAction(title: className, style: .default, handler: { _ in
                self.classPickerField.text = className
            }))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    //Update firebase with new thread
    @objc func postPressed() {
        
        let user = Auth.auth().currentUser
        let userEmail = Auth.auth().currentUser!.email
        
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
                let myPost = Post(username: user, message: self.messageInput.text!)
                
                let threadData: [String: Any] = [
                    "Class": self.classPickerField.text!,
                    "Title": self.titleInput.text!,
                        "University": uni,
                    "Posts": [myPost.toDictionary()]
                    ]
                    
                self.db.collection("Thread").addDocument(data: threadData) { error in
                        if let error = error {
                            //print("Error adding thread: \(error.localizedDescription)")
                        } else {
                            //print("Thread added successfully!")
                            self.navigationController?.popViewController(animated: true) // Dismiss view after succesful post
                        }
                    }
                
            }
        }
        
        
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return userClasses.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return userClasses[row]
    }
    
}
