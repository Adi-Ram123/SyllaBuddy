//
//  PDFViewController.swift
//  SyllaBuddy
//
//  Created by Aditya Ramaswamy on 7/12/25.
//

import UIKit
import UniformTypeIdentifiers
import PDFKit

class PDFViewController: UIViewController, UIDocumentPickerDelegate {

    let confirmSegue = "eventConfirmSegue"
    var eventList = [Event]()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    @IBAction func pdfUpload(_ sender: Any) {
        let supportedTypes: [UTType] = [UTType.pdf]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let selectedURL = urls.first else { return }
        // Load PDF document
        if let pdfDocument = PDFDocument(url: selectedURL) {
            var fullText = ""
            // Extract text from each page
            for pageIndex in 0..<pdfDocument.pageCount {
                if let page = pdfDocument.page(at: pageIndex), let pageText = page.string {
                    fullText += pageText + "\n"
                }
            }
            print("Extracted PDF text:\n\(fullText)")
            let pairs = extractEventDatePairs(from: fullText)
            for (date, event) in pairs {
                print("Date: \(date)\tEvent: \(event)")
                let event = Event(date: date, event: event)
                eventList.append(event)
            }
            performSegue(withIdentifier: confirmSegue, sender: self)
                    
        } else {
            print("Failed to load PDF document.")
        }
    }
    
    func extractEventDatePairs(from text: String) -> [(date: String, event: String)] {
        let months = "(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:t)?(?:ember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)"
            let datePattern = #"\b\#(months) \d{1,2}\b"#

            guard let dateRegex = try? NSRegularExpression(pattern: datePattern, options: .caseInsensitive) else {
                return []
            }

            var results: [(String, String)] = []
            let lines = text.components(separatedBy: .newlines)

            for line in lines {
                let nsrange = NSRange(line.startIndex..., in: line)
                let matches = dateRegex.matches(in: line, options: [], range: nsrange)
                if matches.isEmpty {
                    continue
                }

                let dates = matches.compactMap { match -> String? in
                    guard let range = Range(match.range, in: line) else { return nil }
                    return String(line[range])
                }

                let eventDate = dates.first!
                let eventDescription = line.trimmingCharacters(in: .whitespacesAndNewlines)

                results.append((eventDate, eventDescription))
            }
            return results
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        print("User canceled document picker.")
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == confirmSegue, let nextVC = segue.destination as? EventViewController {
            nextVC.delegate = self
            nextVC.eventList = eventList
        }
    }
    
}
