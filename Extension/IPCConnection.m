//
//  IPCConnection.m
//  Extension
//
//  Created by angle on 2021/2/23.
//  Copyright © 2021 Apple. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IPCConnection.h"
#import "EsIPCProtocol.h"


@interface IPCConnection ()
@property (nonatomic, assign) BOOL bResponse;
@end

@implementation IPCConnection

+ (instancetype)sharedInstance {
    static id share;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        share = [[self alloc] init];
    });
    return share;
}

- (NSString *)extensionMachServiceName {
    NSString *machServiceName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSEndpointSecurityMachServiceName"];
    if (!machServiceName) {
        NSLog(@"Mach service name is missing from the Info.plist");
    }
    return machServiceName;
}

- (void)startListener {
    NSXPCListener *listener = [[NSXPCListener alloc] initWithMachServiceName:[self extensionMachServiceName]];
    listener.delegate = self;
    self.listener = listener;
    [listener resume];
    NSLog(@"startListener end");
}


#pragma mark - NSXPCListenerDelegate

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection {
    //receive message by exportedObject
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(EsIPCProtocol)];
    newConnection.exportedObject = self;
    
    newConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(AppIPCProtocol)];
    newConnection.invalidationHandler = ^{
        self.currentConnection = nil;
    };
    
    newConnection.interruptionHandler = ^{
        self.currentConnection = nil;
    };
    
    self.currentConnection = newConnection;
    [newConnection resume];
    
    NSLog(@"listener shouldAcceptNewConnection self:%@, remoteExportedObj:%@, new connection:%@", self, self.remoteExportedObj, newConnection);
    return YES;
}

#pragma mark - EsIPCProtocol
//extension use it
- (void)sendMsgToApp:(NSString *)msg {
    NSXPCConnection *connection = self.currentConnection;
    if (!connection) {
        NSLog(@"Can't sendMsgToApp because current connection is nil");
        return;
    }

    id<AppIPCProtocol> remoteObj = [connection remoteObjectProxyWithErrorHandler:^(NSError * _Nonnull error) {
        NSLog(@"Failed to register with the provider: %@", [error localizedDescription]);
        [self.currentConnection invalidate];
        self.currentConnection = nil;
    }];
    
    if (!remoteObj) {
        NSLog(@"Failed to create a remote object proxy for the provider");
    }
    
    NSLog(@"sendMsgToApp:%@ remote:%@, self:%@, current connection:%@", msg, self.remoteExportedObj, self, self.currentConnection);
    
    
    [remoteObj messageFromExtension:msg];
    self.bResponse = NO;
    

}
- (void)messageFromApp:(NSString *)msg {
    NSLog(@"messageFromApp %@", msg);
    if ([msg containsString:@"CopyDone"]) {
        self.bResponse = YES;
    }
}

- (void)sleepTillResponse {
    while (!self.bResponse) {
        sleep(1);
    }
}
@end
