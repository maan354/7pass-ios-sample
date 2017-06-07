# 7pass-ios-sample

7Pass iOS Sample is a Swift project to demonstrate how to access
[7Pass SSO service](https://7pass.de) using tokens obtained by [AppAuth](https://github.com/openid/AppAuth-iOS).

## Usage

To run the example project, clone the repo, and run `pod install` first.

## Running

Sample application is configured to run against the QA instance of 7Pass and
uses test credentials (7pass-ios-sample/Configuration.swift). Feel free to use
these credentials while testing but you need to obtain real credentials before
releasing your app.

To obtain the real credentials, you first need to contact the 7Pass
Tech Team.

Once you have the credentials available, you can go ahead and open
`7pass-ios-sample.xcworkspace` project in XCode, select `7pass-ios-sample` build
configuration and run it.

The sample application should now start within the configured device
(or the emulator) and should provide several options each implementing a
feature you might want to use in your app.

## Usage

You are strongly encouraged to go over the sample application to see
how the API should be used.

If you're starting the development, it's always a good idea to work
against a non live instance of the 7Pass SSO service. In this case,
we'll use the QA environment. Don't forget to switch to the production
one before you release your application to the public.

Info about retrieving tokens can be found in the [AppAuth GitHub repo](https://github.com/openid/AppAuth-iOS).

First, let's set some configuration constants and discover 7Pass service:

```swift
let kIssuer = "https://sso.qa.7pass.ctf.prosiebensat1.com"
let kClientId = "56a0982fcd8fb606d000b233"
let kClientSecret = "2e7b77f99be28d80a60e9a2d2c664835ef2e02c05bf929f60450c87c15a59992"
let kRedirectURI = "oauthtest://oauth-callback"
)

let issuer = URL(string: kIssuer)

OIDAuthorizationService.discoverConfiguration(forIssuer: issuer!) {
    serviceConfiguration, error in

    if serviceConfiguration == nil {
        self.logMessage(message: "Error retrieving discovery document: \(error?.localizedDescription)")
        return
    }

    // perform authorization request with serviceConfiguration
}
```

## How to start authentication request

### AppDelegate

AppDelegate is the "heart of the application" and among the other things you can
store there `currentAuthorizationFlow` and `authState`.

```swift
var currentAuthorizationFlow: OIDAuthorizationFlowSession?
var authState: OIDAuthState?
```

It also handles inbound urls from outer world. Such url can be the `redirectURL` with _authorization flow_ specific parameters.

```swift
func application(_ app: UIApplication, open url: URL, options:  [UIApplicationOpenURLOptionsKey : Any]) -> Bool {
    // Sends the URL to the current authorization flow (if any) which will process it if it relates to
    // an authorization response.
    if let currentAuthorizationFlow = currentAuthorizationFlow, currentAuthorizationFlow.resumeAuthorizationFlow(with: url) {
        self.currentAuthorizationFlow = nil
        return true
    }
    return false;
}
```

### Main controller
Once you obtain `serviceConfiguration`, you can perform the authorization call. First you
have to create `authorizationRequest`.

```swift
// builds an authorization request
let authorizationRequest = OIDAuthorizationRequest(configuration: serviceConfiguration!,
            clientId: kClientID,
            scopes: [OIDScopeOpenID, OIDScopeProfile],
            redirectURL: NSURL(string: kRedirectURI),
            responseType: OIDResponseTypeCode,
            additionalParameters: nil
);
```

If you later want to use refresh token you need to provide `offline_access` scope in addition together
with `consent` prompt. Prompt, as well as another custom parameters, can be set using the `additionalParameters`
parameter.

```swift
var additionalParams = [String: String]()
additionalParams["prompt"] = "consent"
additionalParams["utm_campaign"] = "a23_45"
```

Then perform authentication request. The result of the authentication request is stored in the `authorizationResponse` object
which is then used to create `authState` object which retains the state between `OIDAuthorizationResponse`s and `OIDTokenResponse`s.

```swift
 appDelegate.currentAuthorizationFlow = OIDAuthorizationService.present(authorizationRequest, presenting: self) {
    authorizationResponse, error in
    if authorizationResponse != nil {
        // update authState
        self.authState = OIDAuthState(authorizationResponse: authorizationResponse!)
    }
}
```

Once you have the `authorizationResponse` you can perform the token exchange request.

```swift
 let tokenExchangeRequest = OIDTokenRequest(
     configuration: (self.authState?.lastAuthorizationResponse.request.configuration)!,
     grantType: OIDGrantTypeAuthorizationCode,
     authorizationCode: self.authState?.lastAuthorizationResponse.authorizationCode,
     redirectURL: URL(string: kRedirectURI)!,
     clientID: kClientId,
     clientSecret: kClientSecret,
     scope: nil,
     refreshToken: nil,
     codeVerifier: nil,
     additionalParameters: nil
 )

 OIDAuthorizationService.perform(tokenExchangeRequest!) {
   tokenResponse, error in
     if tokenResponse != nil {
        self.authState?.update(with: tokenResponse, error: error)
        // perform authorized api call
     }
 }
```

In `tokenResponse` you will get few of following tokens that are stored in the
`authState`:

1. *Access token* - This token proofs the identity of the user and is
thus included in almost every remote call the library performs. Every access
token has limited validity.

2. *Refresh token* - This token can be used to get a fresh access token.

3. *ID token* - This token contains information (claims) about the
logged in user. You can for example get the user's ID, name, email
etc.

## How to make authorized API calls

The recommend way how to make API calls is to use provided `SevenPassClient`
helper class.

```swift
let accountClient = SevenPassClient(authState: authState);

accountClient.get("/me") { response in
    switch response.result {
    case .success:
        let JSON = response.result.value
        print(JSON)
    case .failure(let error):
    }
}
```

## How to logout

You can use `SevenPassClient.logout` class method that will revoke all of the tokens
and destroy user session in the WebView. After that, just toss your `authState` away.

```swift
SevenPassClient.logout(clientId: kClientId, postLogoutRedirectUri: kRedirectURI, presenting: self, authState: authState)
```

## Facebook login with native app

User can be signed in through native Facebook app instead of an WebView.

Add `fbauth2` to your `LSApplicationQueriesSchemes` in your `Info.plist`
```xml
<key>LSApplicationQueriesSchemes</key>
<array>
        <string>fbauth2</string>
</array>
```

After that, add `fbYOUR_FACEBOOK_APP_ID` into your URL types, fe. `fb734789116545825`.
Edit your authorization, so it sends info about if the `Facebook.app` is available
on user's device.

```swift
let additionalParams = [
    "fbapp_pres": SevenPassClient.isFacebookAppInstalled() ? "1" : "0"
]

let authorizationRequest = OIDAuthorizationRequest(configuration: serviceConfiguration!,
            clientId: kClientID,
            scopes: [OIDScopeOpenID, OIDScopeProfile],
            redirectURL: NSURL(string: kRedirectURI),
            responseType: OIDResponseTypeCode,
            additionalParameters: additionalParams
```

That authorization request has to be presented with custom `OIDAuthorizationUICoordinator`,
please save reference to that coordinator for later use, when we will initiate callback
with Facebook authorization code to 7Pass.

```swift
let coordinator = OIDAuthorizationUICoordinatorIOS(presenting: self)

currentAuthorizationFlow = OIDAuthorizationService.present(authorizationRequest, uiCoordinator: coordinator) {
    authorizationResponse, error in
}
```

And in your `AppDelegate` URL open handler add following to handle redirect from Facebook:

```swift
if let urlScheme = url.scheme, urlScheme.hasPrefix("fb\(config.kFacebookAppId)"),
   let coordinator = authorizationCoordinator,
   let flow = currentAuthorizationFlow {

    SevenPassClient.fbCallback(config.kExternalCallbackURL, coordinator: coordinator, flow: flow, url: url)

    return true
}
```

## License

7pass-ios-sample is available under the MIT license. See the LICENSE file for more info.
