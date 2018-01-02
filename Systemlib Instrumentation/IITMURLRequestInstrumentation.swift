//
//  IITMURLRequestInstrumentation.swift
//  InstrumentITMobileTracer
//
//  Created by NovaTec on 06.11.17.
//  Copyright © 2017 NovaTec. All rights reserved.
//
/*
import UIKit

private let swizzlingInit: (NSURLRequest.Type) -> () = { request in
    
    let originalSelector = #selector(request.init(url:cachePolicy:timeoutInterval:))
    let swizzledSelector = #selector(request.iitmInit(url:cachePolicy:timeoutInterval:))
    
    let originalMethod = class_getInstanceMethod(request, originalSelector)
    let swizzledMethod = class_getInstanceMethod(request, swizzledSelector)
    
    method_exchangeImplementations(originalMethod, swizzledMethod);
    
}


extension NSURLRequest {
    
    open override class func initialize() {
        // make sure this isn't a subclass
        guard self === NSURLRequest.self else { return }
        swizzlingInit(self)
    }
    
    func iitmInit(url: URL, cachePolicy: NSURLRequest.CachePolicy = .useProtocolCachePolicy, timeoutInterval: TimeInterval = 60.0) -> NSURLRequest {
        if url.absoluteString != IITMAgentConstants.HOST && url.absoluteString != "" {
            let invocation = IITMAgent.getInstance().trackInvocation()
            let result = iitmInit(url: url, cachePolicy: cachePolicy, timeoutInterval: timeoutInterval)
            IITMAgent.getInstance().closeInvocation(invocation: invocation!)
            return result
        }
        return iitmInit(url: url, cachePolicy: cachePolicy, timeoutInterval: timeoutInterval)
    }
    
   
}
 */
 

