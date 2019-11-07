//
//  WriteViewController.swift
//  NFCDemo
//
//  Created by vic_liu on 2019/11/5.
//  Copyright © 2019 vic_liu. All rights reserved.
//

import UIKit
import CoreNFC

class WriteViewController: UIViewController {
    
    var readerSession: NFCNDEFReaderSession?
    var lockTag: Bool = false
    
    @IBOutlet weak var WriteDataLabel: UILabel!
    @IBOutlet weak var WriteDataButton: UIButton!
    @IBOutlet weak var WriteLockButton: UIButton!
    @IBOutlet weak var BackButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
    }
    
    @IBAction func writeDataButton(_ sender: Any) {
        beeginScanning()
    }
    
    @IBAction func writeLockButton(_ sender: Any) {
        self.lockTag = true
    }
    
    
    @IBAction func backButton(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func beeginScanning() {
        
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
        //1
        self.readerSession = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        self.readerSession?.alertMessage = "Hold your iPhone near a writable NFC tag to update."
        self.readerSession?.begin()
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
extension WriteViewController: NFCNDEFReaderSessionDelegate {
    
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        
    }
    
    func tagRemovalDetect(_ tag: NFCNDEFTag) {
        // In the tag removal procedure, you connect to the tag and query for
        // its availability. You restart RF polling when the tag becomes
        // unavailable; otherwise, wait for certain period of time and repeat
        // availability checking.
        self.readerSession?.connect(to: tag) { (error: Error?) in
            if error != nil || !tag.isAvailable {
                
                print("Restart polling")
                
                self.readerSession?.restartPolling()
                return
            }
            DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + .milliseconds(500), execute: {
                self.tagRemovalDetect(tag)
            })
        }
    }
    
    // 2.
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        
        if tags.count > 1 {
            session.alertMessage = "More than 1 tags found. Please present only 1 tag."
            self.tagRemovalDetect(tags.first!)
            return
        }
        
        let tag = tags.first!
        // 3
        session.connect(to: tag) { (error: Error?) in
            if error != nil {
                session.restartPolling()
            }
        }
        
        // 4
        tag.queryNDEFStatus() { (status: NFCNDEFStatus, capacity: Int, error: Error?) in
            
            if error != nil {
                session.invalidate(errorMessage: "Fail to determine NDEF status.  Please try again.")
                return
            }
            
            
            let megPayload = NFCNDEFPayload.wellKnownTypeURIPayload(string: "www.udngroup.com")
            //let megPayload = NFCNDEFPayload.wellKnownTypeTextPayload(string: "Hello_from_NFCDemo", locale: Locale(identifier: "En"))
            
            let ndefMessage = NFCNDEFMessage(records: [megPayload!])
            
            let payload = ndefMessage.records[0].payload
            
            let nfcTagData = String.init(data: payload.advanced(by: 1), encoding: .utf8)
            print("--ndefMessage = \(ndefMessage)")
            print("--nfcTagData = \(String(describing: nfcTagData?.description))")
            switch status {
            case .notSupported:
                session.invalidate(errorMessage: "Tag is not NDEF compliant.")
            case .readWrite:
                if ndefMessage.length > capacity {
                    session.invalidate(errorMessage: "Tag capacity is too small.  Minimum size requirement is \(ndefMessage.length) bytes.")
                    return
                }
                // 5
                tag.writeNDEF(ndefMessage) { (error: Error?) in
                    if error != nil {
                        session.invalidate(errorMessage: "Update tag failed. Please try again.")
                    } else {
                        DispatchQueue.main.async { () -> Void in
                            self.WriteDataLabel.text = nfcTagData?.description
                        }
                        session.alertMessage = "Update success!"
                        // 6
                        session.invalidate()
                    }
                    
                }
                
                if (self.lockTag != false) {
                    // locking required also
                    print("Tag needs to be locked")
                    tag.writeLock() { (error: Error?) in
                        if error != nil {
                            print("LOCK FAILED!!")
                            session.alertMessage = "Lock failed try again"
                            session.invalidate()
                            return
                        } else {
                            session.alertMessage = "Write and Lock successful"
                            session.invalidate()
                            return
                        }
                    }
                    return
                }
                
            case .readOnly:
                session.invalidate(errorMessage: "Tag is not writable.")
                
            @unknown default:
                session.invalidate(errorMessage: "Tag is not NDEF formatted.")
                
            }
            
        }
    }
    
}
