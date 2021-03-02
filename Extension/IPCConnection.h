//
//  IPCConnection.h
//  SampleEndpointApp
//
//  Created by angle on 2021/2/23.
//  Copyright © 2021 Apple. All rights reserved.
//

#ifndef IPCConnection_h
#define IPCConnection_h

#import <Foundation/Foundation.h>
#import "EsIPCProtocol.h"
#import "../SampleEndpointApp/AppIPC.h"



@interface IPCConnection : NSObject <NSXPCListenerDelegate, EsIPCProtocol>
@property (nonatomic, strong) NSXPCListener *listener;
@property (nonatomic, strong) NSXPCConnection *currentConnection;
@property (nonatomic, strong) id<AppIPCProtocol> remoteExportedObj;

+ (instancetype)sharedInstance;
- (void)startListener;
- (void)sleepTillResponse;
@end

#endif /* IPCConnection_h */
