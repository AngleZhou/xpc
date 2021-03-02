//
//  AppIPC.h
//  SampleEndpointApp
//
//  Created by angle on 2021/2/23.
//  Copyright © 2021 Apple. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "../Extension/EsIPCProtocol.h"

// Provider --> App IPC
@protocol AppIPCProtocol <NSObject>
- (void)sendMessageToExtension:(NSString *)msg;
- (void)messageFromExtension:(NSString *)msg;
@end


@interface AppIPC : NSObject <AppIPCProtocol>
//@property (nonatomic, weak) id<AppIPCProtocol> delegate;
@property (nonatomic, strong) NSXPCConnection *currentConnection;
@property (nonatomic, strong) id<EsIPCProtocol> remoteExportedObj;

+ (instancetype)sharedInstance;
- (void)registerIPC;
@end


