//
//  ViewController.swift
//  SevenPass
//
//  Created by Jan Votava on 12/21/2015.
//  Copyright (c) 2015 Jan Votava. All rights reserved.
//

import UIKit
import JWTDecode
import AppAuth

class ViewController: UIViewController {
    @IBOutlet weak var refreshButton: UIBarButtonItem!
    @IBOutlet weak var logoutButton: UIBarButtonItem!
    @IBOutlet weak var statusbar: UIBarButtonItem!
    
    let config = Configuration.shared
        
    @IBAction func refresh(_ sender: AnyObject) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate;
        
        if let authState = appDelegate.authState {
            let tokenExchangeRequest = OIDTokenRequest(
                configuration: authState.lastAuthorizationResponse.request.configuration,
                grantType: OIDGrantTypeRefreshToken,
                authorizationCode: nil,
                redirectURL: URL(string: config.kRedirectURI)!,
                clientID: config.kClientId,
                clientSecret: nil,
                scope: nil,
                refreshToken: authState.refreshToken,
                codeVerifier: nil,
                additionalParameters: nil
            )
                        
            OIDAuthorizationService.perform(tokenExchangeRequest) {
                tokenResponse, error in
                if let error = error {
                    showAlert(title: "Error during token refresh", message: error.localizedDescription)
                }
                
                if let tokenResponse = tokenResponse {
                    authState.update(with: tokenResponse, error: error)
                    self.updateStatusbar()
                    showAlert(title: "Refresh Tokens", message: "Tokens we're successfully refreshed.")
                }
            }
        }
    }

    @IBAction func logout(_ sender: AnyObject) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate;
        let config = Configuration.shared

        if let authState = appDelegate.authState {
            appDelegate.currentAuthorizationFlow = SevenPassClient.logout(clientId: config.kClientId, postLogoutRedirectUri: config.kPostLogoutRedirectURI, presenting: self, authState: authState) { response, error in
                
                appDelegate.authState = nil
                self.updateStatusbar()
            }
        }
    }
    
    func updateStatusbar() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate;
        
        if let authState = appDelegate.authState {
            logoutButton.isEnabled = true
            
            if authState.refreshToken != nil {
                refreshButton.isEnabled = true
            }
            
            if let idToken = authState.lastTokenResponse?.idToken {
                do {
                    let decoded = try JWTDecode.decode(jwt: idToken)
                    if let email = decoded.body["email"] as? String {
                        statusbar.title = email
                    }
                } catch {
                    print("Cannot decode idToken");                    
                }
            }
        } else {
            logoutButton.isEnabled = false
            refreshButton.isEnabled = false
            statusbar.title = nil
        }
    }
}

