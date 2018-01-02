
//
//  IITMUIWebViewDelegate.swift
//  InstrumentITMobileTracer
//
//  Created by NovaTec on 06.11.17.
//  Copyright © 2017 NovaTec. All rights reserved.
//

import UIKit

class IITMUIWebViewDelegate: UIViewController, UIWebViewDelegate {
    
    var remotecall: IITMRemoteCall? = nil
    
    func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        return true
    }
    
    func webViewDidStartLoad(_ webView: UIWebView) {
        let url = (webView.request?.url?.absoluteString)!
        self.remotecall = IITMAgent.getInstance().trackRemoteCall(url: url)
    }
    
    func webViewDidFinishLoad(_ webView: UIWebView) {
        IITMAgent.getInstance().closeRemoteCall(remotecall: remotecall!, response: nil, error: nil)
    }
    
    func webView(_ webView: UIWebView, didFailLoadWithError error: Error) {
        let e = error as NSError
        if e.code == URLError.cancelled.rawValue {
            let alert = UIAlertView(title: "Error", message:
                error.localizedDescription, delegate: nil, cancelButtonTitle: "OK")
            alert.show()
        }
    }

}
