//
//  PostViewController.swift
//  SyllaBuddy
//
//  Created by Aditya Ramaswamy on 7/24/25.
//

import UIKit
import FirebaseFirestore
import FirebaseAuth

class PostViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    let stackView = UIStackView()
    let titleLabel = UILabel()
    let tableView = UITableView()
    let messageInput = UITextView()
    let sendButton = UIButton(type: .system)
    var postList: [Post]!
    var threadInfo: Thread!
    let db = Firestore.firestore()
    var user: String!
    var threadListener: ListenerRegistration?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        ThemeManager.shared.applyAll(to: self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupStackView()
        setupSubviews()
        postList = threadInfo.posts
        tableView.register(PostCell.self, forCellReuseIdentifier: "PostCell")
        listenForPostUpdates()
        getAuthUser()
    }
    
    func setupStackView() {
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            stackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8)
        ])
    }
    
    func setupSubviews() {
        // Title Label
        titleLabel.text = "\(threadInfo.title)"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 24)
        titleLabel.textAlignment = .center
        stackView.addArrangedSubview(titleLabel)

        // Table View
        tableView.delegate = self
        tableView.dataSource = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(tableView)

        // Text View
        messageInput.font = UIFont.systemFont(ofSize: 16)
        messageInput.layer.borderColor = UIColor.gray.cgColor
        messageInput.layer.borderWidth = 1
        messageInput.layer.cornerRadius = 8
        messageInput.isScrollEnabled = true  // scrolling enabled
        messageInput.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(messageInput)

        // Button Container
        let buttonContainer = UIView()
        buttonContainer.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.heightAnchor.constraint(equalToConstant: 44).isActive = true

        sendButton.setTitle("Post", for: .normal)
        sendButton.backgroundColor = .systemBlue
        sendButton.setTitleColor(.white, for: .normal)
        sendButton.layer.cornerRadius = 8
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.addTarget(self, action: #selector(postPressed), for: .touchUpInside)

        buttonContainer.addSubview(sendButton)

        NSLayoutConstraint.activate([
            sendButton.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor),
            sendButton.widthAnchor.constraint(equalTo: buttonContainer.widthAnchor, multiplier: 0.25),
            sendButton.heightAnchor.constraint(equalTo: buttonContainer.heightAnchor),
            sendButton.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor)
        ])

        stackView.addArrangedSubview(buttonContainer)

        // Height constraints for tableView and messageInput
        let tableHeightConstraint = tableView.heightAnchor.constraint(equalTo: stackView.heightAnchor, multiplier: 0.65)
        tableHeightConstraint.priority = .defaultHigh
        tableHeightConstraint.isActive = true

        let textHeightConstraint = messageInput.heightAnchor.constraint(equalTo: stackView.heightAnchor, multiplier: 0.20)
        textHeightConstraint.priority = .defaultHigh
        textHeightConstraint.isActive = true
    }
    
    func getAuthUser() {
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
                print("User Classes: \(data["Username"]!)")
                self.user = data["Username"] as? String
            }
        }
    }
    
    @objc func postPressed() {
        // Check if text input is empty
        guard let message = messageInput.text, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("Text Field is empty or only whitespace")
            return
        }

        let collection = db.collection("Thread")

        // Query based on matching class and title (should be unique)
        collection
            .whereField("Class", isEqualTo: threadInfo.className)
            .whereField("Title", isEqualTo: threadInfo.title)
            .getDocuments { (querySnapshot, error) in
                if let error = error {
                    print("Error querying thread: \(error.localizedDescription)")
                    return
                }

                guard let documents = querySnapshot?.documents, !documents.isEmpty else {
                    print("No thread document found matching Class and Title.")
                    return
                }

                let threadDoc = documents[0]
                let docRef = collection.document(threadDoc.documentID)

                let myPost = Post(username: self.user, message: self.messageInput.text)
                

                docRef.updateData([
                    "Posts": FieldValue.arrayUnion([myPost.toDictionary()])
                ]) {
                    error in
                    if let error = error {
                        print("Failed to update thread with new post: \(error.localizedDescription)")
                    } else {
                        print("Successfully added post!")
                        //self.postList.append(myPost)
                        self.messageInput.text = ""
                        // Listener will handle reloading
                    }
                }
            }
    }
    
    //Keeps looking for updates from current and other users
    func listenForPostUpdates() {
        let collection = db.collection("Thread")

        collection
            .whereField("Class", isEqualTo: threadInfo.className)
            .whereField("Title", isEqualTo: threadInfo.title)
            .getDocuments { (querySnapshot, error) in
                if let error = error {
                    print("Error setting up listener: \(error.localizedDescription)")
                    return
                }

                guard let documents = querySnapshot?.documents, !documents.isEmpty else {
                    print("No thread document found for listener.")
                    return
                }

                let threadDoc = documents[0]
                let docRef = collection.document(threadDoc.documentID)

                self.threadListener = docRef.addSnapshotListener { documentSnapshot, error in
                    if let error = error {
                        print("Snapshot listener error: \(error)")
                        return
                    }

                    guard let data = documentSnapshot?.data() else { return }

                    if let postDicts = data["Posts"] as? [[String: Any]] {
                        self.postList = postDicts.map {
                            Post(username: $0["username"] as! String, message: $0["message"] as! String)
                        }
                        DispatchQueue.main.async {
                            self.tableView.reloadData()
                        }
                    }
                }
            }
    }

    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        print(postList.count)
        return postList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PostCell", for: indexPath) as! PostCell
        let post = postList[indexPath.row]
        print(post.message)
        cell.configure(with: post)
        cell.selectionStyle = .none
        return cell
    }

}
