//
//  Configuration.swift
//  SevenPassSDK
//
//  Created by Jan Votava on 06/05/2017.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

final class Configuration {
    // Can't init is singleton
    private init() { }
    
    static let shared = Configuration()
    
    let kIssuer = "https://op.qa.7pass.ctf.prosiebensat1.com"
    let kBaseURL = "https://sso.qa.7pass.ctf.prosiebensat1.com/api/accounts/"
    let kClientId = "5913340f857a8245576ca7fd"
    let kRedirectURI = "de.7pass.example:/cb/authz"
    let kPostLogoutRedirectURI = "de.7pass.example:/cb/end_session"
    
    let kExternalCallbackURL = "https://interaction.qa.7pass.ctf.prosiebensat1.com/externals/callback"
    let kFacebookAppId = "734789116545825"
}
