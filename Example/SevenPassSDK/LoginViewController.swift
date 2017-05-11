//
//  LoginViewController.swift
//  SevenPass
//
//  Created by Jan Votava on 05/01/16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import UIKit
import SevenPassSDK
import AppAuth
import Alamofire

class LoginViewController: UIViewController, UITextFieldDelegate {
    let config = Configuration.shared
    var mainView: ViewController?
    
    override func didMove(toParentViewController parent: UIViewController?) {
        super.didMove(toParentViewController: parent)
        
        mainView = parent as? ViewController
    }
 
    @IBAction func authorize(_ sender: AnyObject) {
        let issuer = URL(string: config.kIssuer)!
        

        
        OIDAuthorizationService.discoverConfiguration(forIssuer: issuer) {
            serviceConfiguration, error in
            if let error = error {
                print("Error retrieving discovery document: \(error.localizedDescription)")
                return
            }
            
            let appDelegate = UIApplication.shared.delegate as! AppDelegate;

            appDelegate.serviceConfiguration = serviceConfiguration
            
            var additionalParams = [String: String]()
            additionalParams["prompt"] = "consent"
            
            let authorizationRequest = OIDAuthorizationRequest(configuration: serviceConfiguration!,
                clientId: self.config.kClientId,
                clientSecret: nil,
                scopes: [OIDScopeOpenID, "offline_access", OIDScopeProfile, OIDScopeEmail],
                redirectURL: URL(string: self.config.kRedirectURI)!,
                responseType: OIDResponseTypeCode,
                additionalParameters: additionalParams)
            
            appDelegate.currentAuthorizationFlow = OIDAuthorizationService.present(authorizationRequest, presenting: self) {
                authorizationResponse, error in
                if let authorizationResponse = authorizationResponse {
                    appDelegate.authState = OIDAuthState(authorizationResponse: authorizationResponse)
                    self.exchangeTokens(
                        authorizationCode: authorizationResponse.authorizationCode,
                        codeVerifier: authorizationRequest.codeVerifier)
                }
            }
        }
    }
    
    func exchangeTokens(authorizationCode: String?, codeVerifier: String?) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate;
        
        let tokenExchangeRequest = OIDTokenRequest(
            configuration: (appDelegate.authState?.lastAuthorizationResponse.request.configuration)!,
            grantType: OIDGrantTypeAuthorizationCode,
            authorizationCode: authorizationCode,
            redirectURL: URL(string: config.kRedirectURI)!,
            clientID: config.kClientId,
            clientSecret: nil,
            scope: nil,
            refreshToken: nil,
            codeVerifier: codeVerifier,
            additionalParameters: nil
            )
        
        OIDAuthorizationService.perform(tokenExchangeRequest!) {
            tokenResponse, error in
            if let error = error {
                print("Error during authorization: \(error.localizedDescription)")
            }
            
            if let tokenResponse = tokenResponse {
                appDelegate.authState?.update(with: tokenResponse, error: error)
                self.mainView?.updateStatusbar()
            }
        }
    }

     @IBAction func request(_ sender: AnyObject? = nil) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate;

        if let authState = appDelegate.authState {
            let accountClient = SevenPassClient(authState: authState);
            appDelegate.accountClient = accountClient

            accountClient.get("/me") { response in
                switch response.result {
                case .success:
                    let JSON = response.result.value
                    showAlert(title: "GET /me", message: "\(JSON)")
                case .failure(let error):
                    showAlert(title: "GET /me", message: "Error fetching fresh tokens:\n\(error)")
                }
            }
        } else {
            showAlert(title: "AuthState is missing", message: "Not logged in")
        }
    }
}
