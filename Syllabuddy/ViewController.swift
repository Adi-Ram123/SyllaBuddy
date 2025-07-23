//
//  ViewController.swift
//  Syllabuddy
//
//  Created by Hai Hoang on 7/13/25.
//

import UIKit
import PDFKit
import Vision

class ViewController: UIViewController, UIDocumentPickerDelegate {
    
    var apiKey: String {
        if let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
           let dict = NSDictionary(contentsOf: url),
           let key = dict["OpenAIAPIKey"] as? String {
            return key
        } else {
            print("Failed to load API key from Secrets.plist")
            return ""
        }
    }
    var prompt = ""
    let url = URL(string: "https://api.openai.com/v1/chat/completions")
    
    @IBOutlet weak var resultLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("API Key: \(apiKey)")
    }
    
    @IBAction func uploadPDFTapped(_ sender: UIButton) {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .image])
        picker.delegate = self
        present(picker, animated: true)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let selectedURL = urls.first else { return }
        
        guard selectedURL.startAccessingSecurityScopedResource() else {
            resultLabel.text = "Couldn't access file."
            return
        }
        defer { selectedURL.stopAccessingSecurityScopedResource() }
        
        let fileExtension = selectedURL.pathExtension.lowercased()
        
        if fileExtension == "pdf" {
            let extractedText = extractTextFromPDF(url: selectedURL)
//            DispatchQueue.main.async {
//                self.resultLabel.text = extractedText
//            }
            self.callChatGPT(with: extractedText)
        } else if ["png", "jpg", "jpeg"].contains(fileExtension) {
            if let image = UIImage(contentsOfFile: selectedURL.path) {
                extractTextFromImage(image) { extractedText in
//                    DispatchQueue.main.async {
//                        self.resultLabel.text = extractedText
//                    }
                    self.callChatGPT(with: extractedText)
                }
            } else {
                resultLabel.text = "Couldn't load image."
            }
        } else {
            resultLabel.text = "Unsupported file type."
        }
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        controller.dismiss(animated: true)
        print("Document picker was cancelled.")
        resultLabel.text = "No file selected."
    }
    
    func extractTextFromPDF(url: URL) -> String {
        guard let doc = PDFDocument(url: url) else { return ""}
        var result = ""
        for i in 0..<doc.pageCount {
            result += doc.page(at: i)?.string ?? ""
        }
        return result
    }
    
    func extractTextFromImage(_ image: UIImage, completion: @escaping (String) -> Void) {
        guard let cgImage = image.cgImage else {
            completion("")
            return
        }
        
        let request = VNRecognizeTextRequest { request, error in
            var result = ""
            for observation in request.results as? [VNRecognizedTextObservation] ?? [] {
                if let text = observation.topCandidates(1).first {
                    result += text.string + "\n"
                }
            }
            completion(result)
        }
        
        request.recognitionLevel = .accurate
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
    }
    
    func callChatGPT(with text: String) {
        guard let url = url else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let prompt = """
        Extract the course number (like CS 371L) and all assignments, exams, and major deadlines from the following syllabus text.
        
        Return the result like a JSON object with two keys:
        - "course": a string with the course number (e.g., "CS 371L")
        - "events": an array of objects where each has a "title" and a "date" (formatted as MM-dd-YYYY)
        
        Example:
        {
            "course": "CS 371L",
            "events": [
                { "title": "Project 1 Due", "date": "06-13-2025" },
                { "title": "Midterm Exam", "date": "07-02-2025" }
            ]
        }
        
        Syllabus Text:
        \(text.prefix(6000)) // Safety cap to avoid any API limitations
        """
        
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": "You are an assistant that extracts structured academic deadlines."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.2
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data else {
                DispatchQueue.main.async {
                    self.resultLabel.text = "No response from API."
                }
                return
            }
            
            if let decoded = try? JSONDecoder().decode(OpenAIResponse.self, from: data) {
                DispatchQueue.main.async {
                    self.resultLabel.text = decoded.choices.first?.message.content
                }
            } else {
                DispatchQueue.main.async {
                    self.resultLabel.text = "Failed to parse response."
                }
            }
        }.resume()
    }
}

struct OpenAIResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}
