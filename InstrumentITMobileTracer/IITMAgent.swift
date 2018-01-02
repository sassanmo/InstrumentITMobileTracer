//
//  Agent.swift
//  AutomaticInvocationTracker
//
//  Created by Matteo Sassano on 15.05.17.
//  Copyright © 2017 Matteo Sassano. All rights reserved.
//

import UIKit

public class IITMAgent: NSObject {
    
    /// Strores the Agent properties
    var agentProperties: [String: Any]
    
    static var agent: IITMAgent?
    
    var invocationOrganizer: IITMInvocationOrganizer
    
    var locationHandler: IITMLocationHandler?
    
    var networkReachability: IITMNetworkReachability?
    
    var dataStorage: IITMDataStorage
    
    var invocationSerializer: IITMInvocationSerializer
    
    /// Collects device Infromation in a specific time interval
    var metricsConrtoller: IITMMetricsController
    
    var restManager: IITMRestManager
    
    var optOut: Bool = false
    
    var dispatchAlways: Bool = true
    
    var webviewdelegate: IITMUIWebViewDelegate?
    
    init(properties: [(String, Any)]? = nil) {
        agentProperties = [String: Any]()
        invocationOrganizer = IITMInvocationOrganizer()
        dataStorage = IITMDataStorage()
        metricsConrtoller = IITMMetricsController()
        invocationSerializer = IITMInvocationSerializer(invocationOrganizer: invocationOrganizer, metricsConroller: metricsConrtoller)
        restManager = IITMRestManager()
        super.init()
        
        if let properties = properties {
            for (property, value) in properties {
                if IITMAgent.allowedProperty(property: property) {
                    agentProperties["property"] = value
                }
            }
        }
        loadAgentId()
        locationHandler = IITMLocationHandler()
        networkReachability = IITMNetworkReachability()
        
        IITMAgent.agent = self
        locationHandler?.requestLocationAuthorization()
    }
    
    public static func getInstance() -> IITMAgent {
        if IITMAgent.agent == nil {
            return IITMAgent()
        } else {
            return IITMAgent.agent!
        }
    }
    
    public func changeOrganization(structure: IITMInvocationOrganizer.IITMDataStructure, model: IITMInvocationOrganizer.IITMDataModel) {
        invocationOrganizer.dataStructure = structure
        invocationOrganizer.dataModel = model
        invocationOrganizer.cleanBuffer()
        invocationOrganizer.cleanUtilities()
        invocationOrganizer.initializeBuffer()
    }
    
    public func changeDispatch(strategy: IITMInvocationOrganizer.IITMDispatchStrategy) {
        invocationOrganizer.dispatchStrategy = strategy
    }
    
    public func allowDispatch(with mobiledata: Bool) {
        dispatchAlways = mobiledata
    }
    
    public static func reinitAgent() {
        IITMAgent.agent = IITMAgent()
    }
    
    func setAgentConfiguration(properties: [(String, Any)]? = nil) {
        if let properties = properties {
            for (property, value) in properties {
                if IITMAgent.allowedProperty(property: property) {
                    agentProperties["property"] = value
                }
            }
        }
    }
    
    public func trackInvocation(function: String = #function, file: String = #file) -> IITMInvocation? {
        if (self.optOut == false) {
            let invocation = IITMInvocation(name: function, holder: file)
            invocationOrganizer.addInvocation(invocation: invocation)
            return invocation
        } else {
            return nil
        }
    }
    
    public func closeInvocation(invocation: IITMInvocation) {
        if (self.optOut == false) {
            invocationOrganizer.removeInvocation(invocation: invocation)
        }
    }
    
    public func trackRemoteCall(function: String = #function, file: String = #file, url: String) -> IITMRemoteCall? {
        if (self.optOut == false) {
            let remotecall = IITMRemoteCall(name: function, holder: file, url: url)
            setRemoteCallStartProperties(remotecall: remotecall)
            invocationOrganizer.correlateRemotecall(remotecall: remotecall)
            return remotecall
        } else {
            return nil
        }
    }
    
    public func closeRemoteCall(remotecall: IITMRemoteCall, response: URLResponse?, error: Error?) {
        if (self.optOut == false) {
            setRemoteCallEndProperties(remotecall: remotecall)
            remotecall.closeRemoteCall(response: response, error: error)
            invocationOrganizer.addRemotecall(remotecall: remotecall)
        }
    }
    
    private func setRemoteCallStartProperties(remotecall: IITMRemoteCall) {
        remotecall.startPosition = locationHandler?.getUsersPosition()
        remotecall.startSSID = IITMSSIDSniffer.getSSID()
        remotecall.startConnectivity = IITMNetworkReachability.getConnectionInformation().0
        remotecall.startProvider = IITMNetworkReachability.getConnectionInformation().1
    }
    
    private func setRemoteCallEndProperties(remotecall: IITMRemoteCall) {
        remotecall.endPosition = locationHandler?.getUsersPosition()
        remotecall.endSSID = IITMSSIDSniffer.getSSID()
        remotecall.endConnectivity = IITMNetworkReachability.getConnectionInformation().0
        remotecall.endProvider = IITMNetworkReachability.getConnectionInformation().1
    }
    
    
    /// TODO:
    static func allowedProperty(property: String) -> Bool {
        return true
    }
    
    
    func injectHeaderAttributes(remotecall: IITMRemoteCall, request: inout NSMutableURLRequest) {
        if (self.optOut == false) {
            let spanid = remotecall.id
            let traceId = remotecall.traceId
            request.addValue(decimalToHex(decimal: spanid), forHTTPHeaderField: "x-inspectit-spanid")
            request.addValue(decimalToHex(decimal: traceId), forHTTPHeaderField: "x-inspectit-traceid")
        }
    }
    
    func spansDispatch() {
        if dispatchAlways || IITMNetworkReachability.getConnectionInformation().0 != "WLAN" {
            
            switch invocationOrganizer.dataModel {
            case .instance:
                if invocationOrganizer.closedTraces?.count != 0 {
                    invocationSerializer.getDataPackage()
                }
            default:
                if invocationOrganizer.closedTracesMessages?.count != 0 {
                    invocationSerializer.getDataPackage()
                }
            }
            
            if invocationSerializer.serializedMeasurements.count != 0 {
                var invocationBuffer = invocationSerializer.serializedMeasurements
                invocationSerializer.serializedMeasurements = [String]()
                
                for (index, item) in invocationBuffer.enumerated() {
                    restManager.httpPostRequest(path: IITMAgentConstants.HOST, body: item, completion: { error -> Void in
                        if error {
                            self.invocationSerializer.serializedMeasurements.append(item)
                        } else {
                            print(item)
                            invocationBuffer.remove(at: index)
                        }
                    })
                }
               
                
            }
        }
    }
    
    /// Loads the Agent ID whitch will be created once
    /// If not any stored than a new ID will be created
    func loadAgentId(){
        if let agentid = dataStorage.loadAgentId() {
            self.agentProperties["id"] = agentid
        } else {
            self.agentProperties["id"] = generateAgentId()
            self.dataStorage.storeAgentId(id: self.agentProperties["id"] as! UInt64)
        }
    }
    
    func generateAgentId() -> UInt64 {
        return calculateUuid()
    }
    
    public func registerWebView(webview: UIWebView) {
        webviewdelegate = IITMUIWebViewDelegate()
        webview.delegate = webviewdelegate
    }
    
}
