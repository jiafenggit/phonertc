import Foundation
import AVFoundation

@objc(PhoneRTCPlugin)
class PhoneRTCPlugin : CDVPlugin {
    var sessions: [String: Session] = [:]
    var peerConnectionFactory: RTCPeerConnectionFactory
    var localAudioTrack: RTCAudioTrack?
    
    override init(webView: UIWebView) {
        peerConnectionFactory = RTCPeerConnectionFactory()
        RTCPeerConnectionFactory.initializeSSL()
        super.init(webView: webView)
    }
    
    func createSessionObject(command: CDVInvokedUrlCommand) {
        if let sessionKey = command.argumentAtIndex(0) as? String {
            // create a session and initialize it.
            if let args = command.argumentAtIndex(1) {
                let config = SessionConfig(data: args)
                let session = Session(plugin: self, peerConnectionFactory: peerConnectionFactory,
                    config: config, callbackId: command.callbackId,
                    sessionKey: sessionKey)
                sessions[sessionKey] = session
            }
        }
    }
    
    func call(command: CDVInvokedUrlCommand) {
        let args: AnyObject = command.argumentAtIndex(0)
        if let sessionKey = args.objectForKey("sessionKey") as? String {
            dispatch_async(dispatch_get_main_queue()) {
                if let session = self.sessions[sessionKey] {
                    session.call()
                }
            }
        }
    }
    
    func receiveMessage(command: CDVInvokedUrlCommand) {
        let args: AnyObject = command.argumentAtIndex(0)
        if let sessionKey = args.objectForKey("sessionKey") as? String {
            if let message = args.objectForKey("message") as? String {
                if let session = self.sessions[sessionKey] {
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                        session.receiveMessage(message)
                    }
                }
            }
        }
    }

    func toggleMute(command: CDVInvokedUrlCommand) {
        let args: AnyObject = command.argumentAtIndex(0);
        if let sessionKey = args.objectForKey("sessionKey") as? String {
            if let mute: Bool = args.objectForKey("mute") as? Bool {
                dispatch_async(dispatch_get_main_queue()) {
                    if let session = self.sessions[sessionKey] {
                        session.toggleMute(mute)
                    }
                }
            }
        }
    }
    
    func disconnect(command: CDVInvokedUrlCommand) {
        let args: AnyObject = command.argumentAtIndex(0)
        if let sessionKey = args.objectForKey("sessionKey") as? String {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                if (self.sessions[sessionKey] != nil) {
                    self.sessions[sessionKey]!.disconnect(true)
                }
            }
        }
    }

    func sendMessage(callbackId: String, message: NSData) {
        let json = NSJSONSerialization.JSONObjectWithData(message,
            options: NSJSONReadingOptions.MutableLeaves,
            error: nil) as NSDictionary
        
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAsDictionary: json)
        pluginResult.setKeepCallbackAsBool(true);
        
        self.commandDelegate.sendPluginResult(pluginResult, callbackId:callbackId)
    }
    
    func initLocalAudioTrack() {
        localAudioTrack = peerConnectionFactory.audioTrackWithID("ARDAMSa0")
    }
    
    func onSessionDisconnect(sessionKey: String) {
        self.sessions.removeValueForKey(sessionKey)
        
        if self.sessions.count == 0 {
            dispatch_sync(dispatch_get_main_queue()) {
                if self.localVideoView != nil {
                    self.localVideoView!.hidden = true
                    self.localVideoView!.removeFromSuperview()
                
                    self.localVideoView = nil
                }
            }
            
            self.localVideoTrack = nil
            self.localAudioTrack = nil
            
            self.videoSource = nil
            self.videoCapturer = nil
        }
    }
}