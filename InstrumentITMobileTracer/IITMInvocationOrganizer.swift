//
//  InvocationMapper.swift
//  AutomaticInvocationTracker
//
//  Created by Matteo Sassano on 15.05.17.
//  Copyright © 2017 Matteo Sassano. All rights reserved.
//

import UIKit

public class IITMInvocationOrganizer: NSObject {
    
    var map : [UInt64 : IITMInvocation]?
    var childMap : [UInt : IITMInvocation]?
    
    var mapMessage : [UInt64 : String]?
    var childMapMessage : [UInt : String]?
    
    var stacks : [UInt : [IITMInvocation]]?
    var stacksMessage : [UInt : [String]]?
    
    
    var closedTraces : [UInt64: [IITMInvocation]]?
    var closedTracesMessages : [UInt64: [String]]?
    
    var messageUtil: IITMMessageUtil?
    var remoteMessageUtil: IITMRemoteMessageUtil?
    
    var doneRemotecalls: [IITMRemoteCall]?
    var doneRemotecallsMessages: [String]?
    
    public enum IITMDataStructure {
        case map
        case stack
    }
    
    public enum IITMDataModel {
        case message
        case instance
        case remoteCallInstanceOnly
    }
    
    public enum IITMDispatchStrategy {
        case closeTrace
        case singleSpan
        case periodic
    }
    
    var dataModel: IITMInvocationOrganizer.IITMDataModel
    var dataStructure: IITMInvocationOrganizer.IITMDataStructure
    var dispatchStrategy: IITMInvocationOrganizer.IITMDispatchStrategy
    
    override convenience init() {
        self.init(structure: .map, model: .instance)
    }
    
    init(structure: IITMDataStructure, model: IITMDataModel) {
        dataStructure = structure
        dataModel = model
        dispatchStrategy = .closeTrace
        super.init()
        initializeBuffer()
    }
    
    func initializeBuffer() {
        switch dataStructure {
        case .map:
            if dataModel == .instance {
                map = [UInt64 : IITMInvocation]()
                childMap = [UInt : IITMInvocation]()
                closedTraces = [UInt64: [IITMInvocation]]()
            } else {
                mapMessage = [UInt64 : String]()
                childMapMessage = [UInt : String]()
                closedTracesMessages = [UInt64: [String]]()
                messageUtil = IITMMessageUtil()
            }
            break
        case .stack:
            if dataModel == .instance {
                stacks = [UInt : [IITMInvocation]]()
                closedTraces = [UInt64: [IITMInvocation]]()
            } else {
                stacksMessage = [UInt : [String]]()
                closedTracesMessages = [UInt64: [String]]()
            }
            break
        }
        switch dataModel {
        case .message:
            doneRemotecallsMessages = [String]()
            remoteMessageUtil = IITMRemoteMessageUtil()
        case .instance:
            doneRemotecalls = [IITMRemoteCall]()
        case .remoteCallInstanceOnly:
            doneRemotecalls = [IITMRemoteCall]()
        }
        
    }
    
    func cleanBuffer() {
        map = nil
        childMap = nil
        closedTraces = nil
        mapMessage = nil
        childMapMessage = nil
        closedTracesMessages = nil
        stacks = nil
        doneRemotecalls = nil
        doneRemotecallsMessages = nil
    }
    
    func cleanUtilities() {
        messageUtil = nil
        remoteMessageUtil = nil
    }
    
    func addInvocation(invocation: IITMInvocation) {
        switch dataStructure {
        case .map:
            addSpanToMap(span: invocation)
            break
        case .stack:
            addSpanToStack(span: invocation)
            break
        }
    }
    
    func addRemotecall(remotecall: IITMRemoteCall) {
        switch dataModel { 
        case .instance:
            doneRemotecalls?.append(remotecall)
            break
        case .remoteCallInstanceOnly:
            doneRemotecalls?.append(remotecall)
            break
        case .message:
            let remotecallMessage = remoteMessageUtil?.getRemoteCall(remotecall: remotecall)
            doneRemotecallsMessages?.append(remotecallMessage!)
            break
        }
        
    }
    
    func correlateRemotecall(remotecall: IITMRemoteCall) {
        switch dataStructure {
        case .map:
            correlateFromMap(remotecall: remotecall)
            break
        case .stack:
            correlateFromStack(remotecall: remotecall)
            break
        }
    }
    
    func correlateFromMap(remotecall: IITMRemoteCall) {
        switch dataModel {
        case .instance:
            if let parent = childMap?[remotecall.threadId] {
                setRelation(child: remotecall, parent: parent)
            } else {
                setRoot(span: remotecall)
            }
            break
        case .remoteCallInstanceOnly:
            if let parent = childMapMessage?[remotecall.threadId] {
                setRelationFromMessage(child: remotecall, parent: parent)
            } else {
                setRoot(span: remotecall)
            }
            break
        case .message:
            if let parent = childMapMessage?[remotecall.threadId] {
                setRelationFromMessage(child: remotecall, parent: parent)
            } else {
                setRoot(span: remotecall)
            }
            break
        }
        
    }
    
    func correlateFromStack(remotecall: IITMRemoteCall) {
        switch dataModel {
        case .instance:
            if let stack = stacks?[remotecall.threadId] {
                if let parent = stack.last {
                    setRelation(child: remotecall, parent: parent)
                } else {
                    setRoot(span: remotecall)
                }
            } else {
                setRoot(span: remotecall)
            }
            break
        case .remoteCallInstanceOnly:
            if let stack = stacksMessage?[remotecall.threadId] {
                if let parent = stack.last {
                    setRelationFromMessage(child: remotecall, parent: parent)
                } else {
                    setRoot(span: remotecall)
                }
            } else {
                setRoot(span: remotecall)
            }
            break
        case .message:
            if let stack = stacksMessage?[remotecall.threadId] {
                if let parent = stack.last {
                    setRelationFromMessage(child: remotecall, parent: parent)
                } else {
                    setRoot(span: remotecall)
                }
            } else {
                setRoot(span: remotecall)
            }
            break
        }
    }
    

    func addSpanToMap(span: IITMInvocation) {
        switch dataModel {
        case .instance:
            if let parent = childMap?[span.threadId] {
                setRelation(child: span, parent: parent)
            } else {
                setRoot(span: span)
            }
            childMap?[span.threadId] = span
            map?[span.id] = span
            break
        default:
            if let parent = childMapMessage?[span.threadId] {
                setRelationFromMessage(child: span, parent: parent)
            } else {
                setRoot(span: span)
            }
            let spanMessage = getSpanMessage(span: span)
            childMapMessage?[span.threadId] = spanMessage
            mapMessage?[span.id] = spanMessage
            break
        }
    }
    
    func addSpanToStack(span: IITMInvocation) {
        switch dataModel {
        case .instance:
            if let stackTrace = stacks?[span.threadId] {
                if let parent = stackTrace.last {
                    setRelation(child: span, parent: parent)
                } else {
                    setRoot(span: span)
                }
            } else {
                stacks?[span.threadId] = [IITMInvocation]()
                setRoot(span: span)
            }
            stacks?[span.threadId]?.append(span)
            break
        default:
            if let stackTrace = stacksMessage?[span.threadId] {
                if let parentMessage = stackTrace.last {
                    setRelationFromMessage(child: span, parent: parentMessage)
                } else {
                    setRoot(span: span)
                }
            } else {
                stacksMessage?[span.threadId] = [String]()
                setRoot(span: span)
            }
            let spanMessage = messageUtil?.getSpanString(span: span)
            stacksMessage?[span.threadId]?.append(spanMessage!)
            break
        }
    }
    
    
    func removeInvocation(invocation: IITMInvocation) {
        switch dataStructure {
        case .map:
            removeSpanFromMap(span: invocation)
            break
        case .stack:
            removeSpanFromStack(span: invocation)
            break
        }
    }
    
    func removeSpanFromMap(span: IITMInvocation) {
        switch dataModel {
        case .instance:
            if let invocation = map?[span.id] {
                if childMap?[invocation.threadId]?.id == invocation.id {
                    invocation.closeInvocation()
                    childMap?[invocation.threadId] = nil
                    map?[span.id] = nil
                    addCompleteSpanToBuffer(span: invocation)
                    if invocation.id == invocation.parentId {
                        closeTrace(threadId: invocation.threadId)
                    } else {
                        if let parent = map?[invocation.parentId] {
                            childMap?[invocation.threadId] = parent
                        } else {
                            print("[ERROR] parent invocation with id \(invocation.parentId ) not found")
                        }
                    }
                } else {
                    print("[ERROR] invocation is not last child")
                }
            } else {
                print("[ERROR] invocation with id \(span.id) not found")
            }
            break
        default:
            if let invocation = mapMessage?[span.id] {
                if messageUtil?.getId(span: (childMapMessage?[(messageUtil?.getThreadId(span: invocation))!])!) == span.id {
                    span.closeInvocation()
                    childMapMessage?[span.threadId] = nil
                    mapMessage?[span.id] = nil
                    addCompleteSpanToBuffer(span: span)
                    if span.id == span.parentId {
                        closeTrace(threadId: span.threadId)
                    } else {
                        if let parent = mapMessage?[span.parentId] {
                            childMapMessage?[span.threadId] = parent
                            
                        } else {
                            print("[ERROR] parent invocation with id \(span.parentId) not found")
                        }
                    }
                } else {
                    print("[ERROR] invocation is not last child")
                }
            } else {
                print("[ERROR] invocation with id \(span.id) not found")
            }
            break
        }
        if dispatchStrategy == .singleSpan {
            IITMAgent.getInstance().spansDispatch()
        }
    }
    
    func removeSpanFromStack(span: IITMInvocation) {
        switch dataModel {
        case .instance:
            if let invocation = stacks?[span.threadId]?.last {
                if span.id == invocation.id {
                    span.closeInvocation()
                    addCompleteSpanToBuffer(span: invocation)
                    stacks?[span.threadId]?.removeLast()
                    if span.id == span.parentId {
                        closeTrace(threadId: span.threadId)
                    } else {
                    }
                } else {
                    print("[ERROR] invocation is not last child")
                }
            } else {
                print("[ERROR] invocation with id \(span.id) not found")
            }
            break
        default:
            if let invocation = stacksMessage?[span.threadId]?.last {
                if span.id == messageUtil?.getId(span: invocation) {
                    span.closeInvocation()
                    addCompleteSpanToBuffer(span: span)
                    stacks?[span.threadId]?.removeLast()
                    if span.id == span.parentId {
                        closeTrace(threadId: span.threadId)
                    } else {
                    }
                } else {
                    print("[ERROR] invocation is not last child")
                }
            } else {
                print("[ERROR] invocation with id \(span.id) not found")
            }
            break
        }
        if dispatchStrategy == .singleSpan {
            IITMAgent.getInstance().spansDispatch()
        }
    }
    
    
    func closeTrace(threadId: UInt) {
        if dispatchStrategy == .closeTrace {
            // TODO
            IITMAgent.getInstance().spansDispatch()
        }
    }
    
    
    func addCompleteSpanToBuffer(span: IITMInvocation) {
        switch dataModel {
        case .instance:
            if (closedTraces?[span.traceId]) != nil {
                closedTraces?[span.traceId]?.append(span)
            } else {
                closedTraces?[span.traceId] = [IITMInvocation]()
                closedTraces?[span.traceId]?.append(span)
            }
        default:
            let spanMessage = messageUtil?.completeSpanString(span: span)
            if (closedTracesMessages?[span.traceId]) != nil {
                closedTracesMessages?[span.traceId]?.append(spanMessage!)
            } else {
                closedTracesMessages?[span.traceId] = [String]()
                closedTracesMessages?[span.traceId]?.append(spanMessage!)
            }
        }
        
    }
    
    func addCompleteSpanMessageToBuffer(spanMessage: String) {
        if var trace = closedTracesMessages?[(messageUtil?.getTraceId(span: spanMessage))!] {
            trace.append(spanMessage)
        } else {
            closedTracesMessages?[(messageUtil?.getTraceId(span: spanMessage))!] = [String]()
            closedTracesMessages?[(messageUtil?.getTraceId(span: spanMessage))!]?.append(spanMessage)
        }
    }
    
    
    func setRelation(child: IITMInvocation, parent: IITMInvocation) {
        child.parentId = parent.id
        child.traceId = parent.traceId
    }
    
    func setRelationFromMessage(child: IITMInvocation, parent: String) {
        if messageUtil != nil {
            child.parentId = (messageUtil?.getId(span: parent))!
            child.traceId = (messageUtil?.getTraceId(span: parent))!
        }
    }
    
    func setRoot(span: IITMInvocation) {
        span.parentId = UInt64(span.id)
        span.traceId = UInt64(span.id)
    }
    
    
    func getSpanMessage(span: IITMInvocation) -> String {
        if messageUtil != nil {
            if let spanstring = messageUtil?.getSpanString(span: span) {
                return spanstring
            }
        }
        return "error span"
    }

}
