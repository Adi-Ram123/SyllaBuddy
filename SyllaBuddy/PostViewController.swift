//
//  PostViewController.swift
//  SyllaBuddy
//
//  Created by Aditya Ramaswamy on 7/24/25.
//

import UIKit

class PostViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    let stackView = UIStackView()
    let titleLabel = UILabel()
    let tableView = UITableView()
    let messageInput = UITextView()
    let sendButton = UIButton(type: .system)
    var postList: [Post]!
    var threadInfo: Thread!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupStackView()
        setupSubviews()
        postList = threadInfo.posts
        tableView.register(PostCell.self, forCellReuseIdentifier: "PostCell")

        // Do any additional setup after loading the view.
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

        sendButton.setTitle("Send", for: .normal)
        sendButton.backgroundColor = .systemBlue
        sendButton.setTitleColor(.white, for: .normal)
        sendButton.layer.cornerRadius = 8
        sendButton.translatesAutoresizingMaskIntoConstraints = false

        buttonContainer.addSubview(sendButton)

        NSLayoutConstraint.activate([
            sendButton.centerXAnchor.constraint(equalTo: buttonContainer.centerXAnchor),
            sendButton.widthAnchor.constraint(equalTo: buttonContainer.widthAnchor, multiplier: 0.25),
            sendButton.heightAnchor.constraint(equalTo: buttonContainer.heightAnchor)
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
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
