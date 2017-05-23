//
//  Util.swift
//  SevenPass
//
//  Created by Jan Votava on 26/01/16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import UIKit

func showAlert(title: String, message: String) {
    if let topController = UIApplication.shared.keyWindow?.rootViewController {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let defaultAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(defaultAction)

        // Delay alert by 0.5s, so it doesn't collide with a WebView presentation
        let dispatchTime = DispatchTime.now() + Double(500000000) / Double(NSEC_PER_SEC)

        DispatchQueue.main.asyncAfter(deadline: dispatchTime, execute: {
            topController.present(alertController, animated: true, completion: nil)
        })
    }
}

func errorHandler(_ error: NSError) {
    showAlert(title: "Error", message: error.localizedDescription)
}
