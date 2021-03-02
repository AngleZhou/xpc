//
//  AppIPC.m
//  SampleEndpointApp
//
//  Created by angle on 2021/2/23.
//  Copyright © 2021 Apple. All rights reserved.
//

#import "AppIPC.h"

void writeDataFromFiletoFile(NSString *nsTromFile, NSString *nsToFile);
BOOL isSparseFile(NSString *filePath);

@interface AppIPC ()
@property (nonatomic, strong) dispatch_queue_t esEventQueue;
@end
@implementation AppIPC

+ (instancetype)sharedInstance {
    static id share;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        share = [[self alloc] init];
    });
    return share;
}
- (instancetype)init
{
    self = [super init];
    if (self) {
        self.esEventQueue = dispatch_queue_create("esEventQueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (NSBundle *)extensionBundle {
    NSURL *extensionDirUrl = [NSURL fileURLWithPath:@"Contents/Library/SystemExtensions" relativeToURL:[[NSBundle mainBundle] bundleURL]];
    NSError *error;
    NSArray<NSURL *> *extensions = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:extensionDirUrl includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:&error];
    if (!extensions) {
        NSLog(@"Failed to get the contents of %@", extensionDirUrl);
        return nil;
    }
    if ([extensions count] == 0) {
        NSLog(@"Failed to find any system extensions");
        return nil;
    }
    NSURL *extensionUrl = [extensions firstObject];
    return [NSBundle bundleWithURL:extensionUrl];
}

- (void)registerIPC {
    NSString *machServiceName = [[self extensionBundle] objectForInfoDictionaryKey:@"NSEndpointSecurityMachServiceName"];
    if (!machServiceName) {
        NSLog(@"Mach service name is missing from the Info.plist");
        return;
    }
    NSXPCConnection *newConnection = [[NSXPCConnection alloc] initWithMachServiceName:machServiceName options:0];
    //receive message by exportedObject
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(AppIPCProtocol)];
    newConnection.exportedObject = self;
    
    //Other side of the connection
    newConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(EsIPCProtocol)];
    self.currentConnection = newConnection;
    [newConnection resume];
    
    id<EsIPCProtocol> remoteObj = [newConnection remoteObjectProxyWithErrorHandler:^(NSError * _Nonnull error) {
        NSLog(@"Failed to register with the provider: %@", [error localizedDescription]);
        [self.currentConnection invalidate];
        self.currentConnection = nil;
    }];
    if (!remoteObj) {
        NSLog(@"Failed to create a remote object proxy for the provider");
    } else {
        self.remoteExportedObj = remoteObj;
    }
    
    [remoteObj sendMsgToApp:@"Hello"];
    NSLog(@"register self:%@, remoteExportedObj:%@, connection:%@", self, self.remoteExportedObj, newConnection);
    
}

#pragma mark - AppIPCProtocol

- (void)sendMessageToExtension:(NSString *)msg {
    //会无限循环
    [self.remoteExportedObj messageFromApp:msg];
}

- (void)messageFromExtension:(NSString *)msg {
    NSLog(@"messageFromExtension %@", msg);
    if ([msg isEqualToString:@"Hello"]) {
        return;
    }
    
    NSString *filePath = msg;
    if (isSparseFile(filePath)) {
        dispatch_async(self.esEventQueue, ^{
            NSLog(@"== App writes file and responses");
            writeDataFromFiletoFile(@"/Users/angle/Desktop/test/origin/all.txt", filePath);
            [self sendMessageToExtension:@"== messageFromApp: CopyDone"];
        });
    } else {
        NSLog(@"file %@ is not a sparse file", filePath);
    }


}

#pragma mark - Helper
void writeDataFromFiletoFile(NSString *nsTromFile, NSString *nsToFile) {
    const char *fromFilePath = [nsTromFile UTF8String];
    const char *toFilePath = [nsToFile UTF8String];
    FILE *toFile = fopen(toFilePath, "wb");
    FILE *fromFile = fopen(fromFilePath, "rb");
    char buffer[256];
    if (!toFile || !fromFile) {
        NSLog(@"file not exist");
    } else {
        while (fgets(buffer, sizeof(buffer), fromFile)) {
            fprintf(toFile, "%s", buffer);
        }
    }
    
    fclose(toFile);
    fclose(fromFile);
}

NSDictionary<NSURLResourceKey, id>* getFileAttribute(NSString *filePath, NSArray *resourceKeys) {
    NSError *error;
    NSURL *url = [NSURL fileURLWithPath:filePath];
    NSDictionary<NSURLResourceKey, id> *resources = [url resourceValuesForKeys:resourceKeys error:&error];
    if (!resources) {
        NSLog(@"%@", error);
    }
    return resources;
}

BOOL isSparseFile(NSString *filePath) {
    if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        NSLog(@"file %@ not exist", filePath);
        return NO;
    }

    NSArray *keys = @[
                      NSURLFileSizeKey,
                      NSURLFileAllocatedSizeKey
    ];
    NSDictionary<NSURLResourceKey, id>* attributes = getFileAttribute(filePath, keys);
    long sizeInBytes = [attributes[NSURLFileSizeKey] longValue];
    long diskSizeInBytes = [attributes[NSURLFileAllocatedSizeKey] longValue];
    if (diskSizeInBytes == 0 && sizeInBytes != 0) {
        return YES;
    }
    return NO;
}

@end
