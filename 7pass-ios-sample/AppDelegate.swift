//
//  AppDelegate.swift
//  SevenPass
//
//  Created by Jan Votava on 12/21/2015.
//  Copyright (c) 2015 Jan Votava. All rights reserved.
//

import UIKit
import AppAuth

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    let config = Configuration.shared
    var window: UIWindow?

    var serviceConfiguration: OIDServiceConfiguration?
    var currentAuthorizationFlow: OIDAuthorizationFlowSession?
    var authState: OIDAuthState?
    var accountClient: SevenPassClient?
    var authorizationCoordinator: OIDAuthorizationUICoordinator?
    
    func application(_ app: UIApplication, open url: URL, options:  [UIApplicationOpenURLOptionsKey : Any]) -> Bool {
        // Handle facebook redirect
        if let urlScheme = url.scheme, urlScheme.hasPrefix("fb\(config.kFacebookAppId)"),
           let coordinator = authorizationCoordinator,
           let flow = currentAuthorizationFlow { // facebook
            
            SevenPassClient.fbCallback(config.kExternalCallbackURL, coordinator: coordinator, flow: flow, url: url)

            return true
        }

        if let currentAuthorizationFlow = currentAuthorizationFlow, currentAuthorizationFlow.resumeAuthorizationFlow(with: url) {
        // Sends the URL to the current authorization flow (if any) which will process it if it relates to
        // an authorization response.
            self.currentAuthorizationFlow = nil
            return true
        }
        
        return false
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
}

