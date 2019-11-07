//
//  ViewController.swift
//  NFCDemo
//
//  Created by vic_liu on 2019/11/4.
//  Copyright © 2019 vic_liu. All rights reserved.
//

import UIKit
import CoreNFC

class ViewController: UIViewController {
    
    var readerSession: NFCTagReaderSession?
    var detectedMessages = [NFCNDEFMessage]()
    var result: String = ""
    
    @IBOutlet weak var TagDataLabel: UILabel!
    
    @IBOutlet weak var TagTypeLabel: UILabel!
    
    @IBOutlet weak var ReadTagButton: UIButton!
    
    @IBOutlet weak var WriteTagButton: UIButton!
    
    @IBOutlet weak var ClearDataButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
    }
    
    func updateWithNDEFMessage(_ message: NFCNDEFMessage) -> Bool {
        self.detectedMessages.removeAll()
        self.detectedMessages.append(message)
        print("--self.detectedMessages = \(self.detectedMessages)")
        for payload in detectedMessages[0].records {
            let nfcTagType = String.init(data: payload.type.advanced(by: 0), encoding: .utf8)
            let nfcTagData = String.init(data: payload.payload, encoding: .utf8)
            print("--nfcTagType + nfcTagData  = \(nfcTagType) + \(nfcTagData)--")
            switch nfcTagType {
            case "U":
                result += (payload.wellKnownTypeURIPayload()?.absoluteURL.absoluteString)!
            case "T":
                result += payload.wellKnownTypeTextPayload().0!
            default:
                result += String.init(data: payload.payload.advanced(by: 3), encoding: .utf8)!
            }
        }
        print("----result = \(result)----")
        DispatchQueue.main.async { () -> Void in
            self.TagDataLabel.text = self.result
        }
       
        return true
          }
    
    @IBAction func readTagButton(_ sender: Any) {
        guard NFCNDEFReaderSession.readingAvailable else {
            let alertController = UIAlertController(
                title: "Scanning Not Supported",
                message: "This device doesn't support tag scanning.",
                preferredStyle: .alert
            )
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alertController, animated: true, completion: nil)
            return
        }
        readerSession = NFCTagReaderSession(pollingOption: [.iso14443, .iso15693, .iso18092], delegate: self, queue: nil)
        readerSession?.alertMessage = "Hold your iPhone near an NFC fish tag."
        readerSession?.begin()
    }
    
    @IBAction func writeTagButton(_ sender: Any) {
        
        if let vc = storyboard?.instantiateViewController(withIdentifier: "writeVC") as? WriteViewController {
            
            self.present(vc,animated: true, completion: nil)
            
        }
        
    }
    
    
    @IBAction func clearDataButton(_ sender: Any) {
        self.result = " "
        self.TagDataLabel.text = self.result
       
    }
    
}





// MARK: - NFCTagReaderSessionDelegate
extension ViewController : NFCTagReaderSessionDelegate {
    
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
//          print("The session was invalidated: \(error)")
    }
    
    
    func tagRemovalDetect(_ tag: NFCTag) {
           self.readerSession?.connect(to: tag) { (error: Error?) in
               if error != nil || !tag.isAvailable {
                   
                  print("Restart polling.")
                   
                   self.readerSession?.restartPolling()
                   return
               }
               DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + .milliseconds(500), execute: {
                   self.tagRemovalDetect(tag)
               })
           }
       }
    
    
  func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        if tags.count > 1 {
            session.alertMessage = "More than 1 tags was found. Please present only 1 tag."
            self.tagRemovalDetect(tags.first!)
            return
        }
        
        var ndefTag: NFCNDEFTag
        switch tags.first! {
        case let .iso7816(tag):
            ndefTag = tag
        case let .feliCa(tag):
            ndefTag = tag
        case let .iso15693(tag):
            ndefTag = tag
        case let .miFare(tag):
            ndefTag = tag
        @unknown default:
            session.invalidate(errorMessage: "Tag not valid.")
            return
        }
        print("----NFCTagType = \(ndefTag)----")
    DispatchQueue.main.async { () -> Void in
    self.TagTypeLabel.text = ndefTag.description
    }
  
        session.connect(to: tags.first!) { (error: Error?) in
            if error != nil {
                session.invalidate(errorMessage: "Connection error. Please try again.")
                return
            }
            
            ndefTag.queryNDEFStatus() { (status: NFCNDEFStatus, _, error: Error?) in
                if status == .notSupported {
                    session.invalidate(errorMessage: "Tag not valid.")
                    return
                }
                ndefTag.readNDEF() { (message: NFCNDEFMessage?, error: Error?) in
                    if error != nil || message == nil {
                        session.invalidate(errorMessage: "Read error. Please try again.")
                        return
                    }
                       
                    if self.updateWithNDEFMessage(message!) {
                        session.alertMessage = "Tag read success."
                        session.invalidate()
                        return
                    }
                    
                    session.invalidate(errorMessage: "Tag not valid.")
                }
            }
        }
    }


     
      
   
    
    
    
    
    
    
}
