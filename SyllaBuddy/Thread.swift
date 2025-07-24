//
//  Thread.swift
//  SyllaBuddy
//
//  Created by Aditya Ramaswamy on 7/24/25.
//

import Foundation

class Thread {
    
    var className: String
    var posts: [Post]
    var title: String
    var university: String
    
    init(className: String, posts: [Post], title: String, university: String) {
        self.className = className
        self.posts = posts
        self.title = title
        self.university = university
    }
    
}
