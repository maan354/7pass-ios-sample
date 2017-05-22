//
//  OAuthSwiftClient.swift
//  OAuthSwift
//
//  Created by Dongri Jin on 6/21/14.
//  Copyright (c) 2014 Dongri Jin. All rights reserved.
//

import AppAuth
import Alamofire
import CryptoSwift

extension URL {
    public var queryItems: [String: String] {
        var params = [String: String]()
        return URLComponents(url: self, resolvingAgainstBaseURL: false)?
            .queryItems?
            .reduce([:], { (_, item) -> [String: String] in
                params[item.name] = item.value
                return params
            }) ?? [:]
    }
}

open class SevenPassClient {
    open static func isFacebookAppInstalled() -> Bool {
        return UIApplication.shared.canOpenURL(URL(string: "fbauth2://")!)
    }
    
    open static func fbCallback(
        _ callbackUrl: String,
        coordinator: OIDAuthorizationUICoordinator,
        flow: OIDAuthorizationFlowSession,
        url: URL) {
        
        var state = url.queryItems["state"]
        var code = url.queryItems["code"]
        var appType = "web"
        
        // Code/state from native app is inside fragments
        if state == nil {
            var url = url
            url = URL(string: url.absoluteString.replacingOccurrences(of: "#", with: "?"))!

            state = url.queryItems["state"]
            code = url.queryItems["code"]
            
            appType = "native"
        }

        if let code = code, let state = state {
            let callback = "\(callbackUrl)?code=\(code)&state=\(state)&fbapp_type=\(appType)"
        
            coordinator.dismissAuthorization(animated: false) {
                coordinator.presentAuthorization(with: URL(string: callback)!, session: flow)
            }
        }
    }

    
    open static func logout(clientId: String,
                            postLogoutRedirectUri: String,
                            presenting: UIViewController,
                            authState: OIDAuthState,
                            callback: @escaping OIDAuthorizationCallback) -> OIDAuthorizationFlowSession? {
        
        if let lastTokenResponse = authState.lastTokenResponse {
            let configuration = lastTokenResponse.request.configuration
            
            // Revoke tokens
            if let accessToken = lastTokenResponse.accessToken {
                self.revoke(configuration: configuration, clientId: clientId, token: accessToken, tokenType: "access_token")
            }
            
            if let refreshToken = lastTokenResponse.refreshToken {
                self.revoke(configuration: configuration, clientId: clientId, token: refreshToken, tokenType: "refresh_token")
            }
            
            // Logout session
            if let idToken = lastTokenResponse.idToken,
               let endSessionEndpoint = configuration.discoveryDocument?.discoveryDictionary["end_session_endpoint"] as? String {
                
                let serviceConfiguration = OIDServiceConfiguration(authorizationEndpoint: URL(string: endSessionEndpoint)!, tokenEndpoint: URL(string: postLogoutRedirectUri)!)
                
                    let authorizationRequest = OIDAuthorizationRequest(configuration: serviceConfiguration,
                                                                   clientId: clientId,
                                                                   scopes: nil,
                                                                   redirectURL: URL(string: postLogoutRedirectUri)!,
                                                                   responseType: "",
                                                                   additionalParameters: [
                                                                    "id_token_hint": idToken,
                                                                    "post_logout_redirect_uri": postLogoutRedirectUri
                    ]);
                
                return OIDAuthorizationService.present(authorizationRequest, presenting: presenting, callback: callback)
            }
        }
        
        return nil
    }
    
    open static func revoke(configuration: OIDServiceConfiguration, clientId: String, token: String, tokenType: String) {
        if let revocationEndpoint = configuration.discoveryDocument?.discoveryDictionary["revocation_endpoint"] as? String {
            let parameters = [
                "client_id": clientId,
                "token": token,
                "token_type_hint": tokenType
            ]
            
            Alamofire.request(revocationEndpoint,
                              method: .post,
                              parameters: parameters,
                              encoding: URLEncoding.default)
        }
    }
    
    public typealias CompletionHandler = (DataResponse<Any>) -> Void
    
    var authState: OIDAuthState?
    var accessToken: String?
    var baseURL: URL?

    public init(accessToken: String, baseURL: URL? = nil) {
        self.accessToken = accessToken
        self.baseURL = baseURL
    }
    
    public init(authState: OIDAuthState, baseURL: URL? = nil) {
        self.authState = authState
        
        if let baseURL = baseURL {
            self.baseURL = baseURL
        } else if let lastTokenResponse = authState.lastTokenResponse {
            let configuration = lastTokenResponse.request.configuration
            self.baseURL = configuration.discoveryDocument?.issuer
        }
    }
    
    @discardableResult
    open func request(
        _ urlString: String,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil,
        completionHandler: @escaping CompletionHandler) -> Self {
        
        var parameters = parameters ?? [:]
        var headers = headers ?? [:]

        if let accessToken = self.accessToken {
            headers["Authorization"] = "Bearer " + accessToken
        }
        
        var urlString = urlString
        if let baseURL = baseURL {
            urlString = URL(string: urlString, relativeTo: self.baseURL)!.absoluteString
        }        

        Alamofire.request(urlString, method: method, parameters: parameters, headers: headers).responseJSON(completionHandler: completionHandler)
        
        return self
    }
    
    @discardableResult
    open func requestWithFreshTokenSet(
        _ urlString: String,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil,
        completionHandler: @escaping CompletionHandler) -> Self {
        
        if let authState = self.authState {
            authState.performAction(freshTokens: {
                accessToken, idToken, error in

                if let error = error {
                    let result = Result<Any>.failure(error)
                    let response = DataResponse(request: nil, response: nil, data: nil, result: result)

                    completionHandler(response)
                } else {
                    self.accessToken = accessToken
                    self.request(urlString, method: method, parameters: parameters, headers: headers, completionHandler: completionHandler)
                }
            })
        } else {
            request(urlString, method: method, parameters: parameters, headers: headers, completionHandler: completionHandler)
        }
        
        return self
    }

    @discardableResult
    open func get(
        _ urlString: String,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil,
        completionHandler: @escaping CompletionHandler) -> Self {
        
        return requestWithFreshTokenSet(urlString, method: .get, parameters: parameters, headers: headers, completionHandler: completionHandler)
    }
    
    @discardableResult
    open func post(
        _ urlString: String,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil,
        completionHandler: @escaping CompletionHandler) -> Self {
        
        return requestWithFreshTokenSet(urlString, method: .post, parameters: parameters, headers: headers, completionHandler: completionHandler)
    }
    
    @discardableResult
    open func put(
        _ urlString: String,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil,
        completionHandler: @escaping CompletionHandler) -> Self {
        
        return requestWithFreshTokenSet(urlString, method: .put, parameters: parameters, headers: headers, completionHandler: completionHandler)
    }

    @discardableResult
    open func patch(
        _ urlString: String,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil,
        completionHandler: @escaping CompletionHandler) -> Self {
        
        return requestWithFreshTokenSet(urlString, method: .patch, parameters: parameters, headers: headers, completionHandler: completionHandler)
    }

    @discardableResult
    open func delete(
        _ urlString: String,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil,
        completionHandler: @escaping CompletionHandler) -> Self {
        
        return requestWithFreshTokenSet(urlString, method: .delete, parameters: parameters, headers: headers, completionHandler: completionHandler)
    }
}
