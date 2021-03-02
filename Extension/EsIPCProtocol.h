//
//  ProviderCommunicationProtocol.h
//  SampleEndpointApp
//
//  Created by angle on 2021/2/23.
//  Copyright © 2021 Apple. All rights reserved.
//

#ifndef ProviderCommunicationProtocol_h
#define ProviderCommunicationProtocol_h

#import <Foundation/Foundation.h>

// App --> Provider IPC
@protocol EsIPCProtocol
- (void)sendMsgToApp:(NSString *)msg;
- (void)messageFromApp:(NSString *)msg;
@end

#endif /* ProviderCommunicationProtocol_h */
