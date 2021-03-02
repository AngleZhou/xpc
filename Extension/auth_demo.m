/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Functions that initialize the Endpoint Security system extension to receive AUTH events.
*/

#include <EndpointSecurity/EndpointSecurity.h>
#include <dispatch/queue.h>
#include <bsm/libbsm.h>
#include <stdio.h>
#include <os/log.h>
#import <Foundation/Foundation.h>
#import "IPCConnection.h"

#define CSTR2NSSTR(cstr) [NSString stringWithCString:cstr encoding:NSUTF8StringEncoding]

es_client_t *g_client = nil;
static dispatch_queue_t g_event_queue = NULL;

static void
init_dispatch_queue(void)
{
	// Choose an appropriate Quality of Service class appropriate for your app.
	// https://developer.apple.com/documentation/dispatch/dispatchqos
	dispatch_queue_attr_t queue_attrs = dispatch_queue_attr_make_with_qos_class(
			DISPATCH_QUEUE_CONCURRENT, QOS_CLASS_USER_INITIATED, 0);

	g_event_queue = dispatch_queue_create("event_queue", queue_attrs);
}

static bool
is_eicar_file(const es_file_t *file)
{
    // The EICAR test file string, as defined by the EICAR standard.
	static const char* eicar = "X5O!P%@AP[4\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*";
	static const off_t eicar_length = sizeof(eicar) - 1;
	static const off_t eicar_max_length = 128;

	bool result = false;

	// EICAR check
	// First: ensure the length matches defined EICAR requirements.
	if (file->stat.st_size >= eicar_length && file->stat.st_size <= eicar_max_length) {
		//Second: Open the file and read the data.
		int fd = open(file->path.data, O_RDONLY);
		if (fd >= 0) {
			uint8_t buf[sizeof(eicar)];
			ssize_t bytes_read = read(fd, buf, sizeof(buf));
			if (bytes_read >= eicar_length) {
				//Third: Test the file contents against the EICAR test string.
				if (memcmp(buf, eicar, sizeof(buf)) == 0) {
					result = true;
				}
			}

			close(fd);
		}
	}

	return result;
}

static void
handle_exec(es_client_t *client, const es_message_t *msg)
{
    // To keep the code simple, this example denies execution based on signing ID.
    // However this isn't a very restrictive policy and could inadvertently lead to
    // denying more executions than intended. In general, you should consider using
    // more restrictive policies like inspecting the process's CDHash instead.
//	static const char *signing_id_to_block = "com.apple.TextEdit";
//
//	if (strcmp(msg->event.exec.target->signing_id.data, signing_id_to_block) == 0) {
//		es_respond_auth_result(client, msg, ES_AUTH_RESULT_DENY, true);
//	} else {
//		es_respond_auth_result(client, msg, ES_AUTH_RESULT_ALLOW, true);
//	}
    es_respond_auth_result(client, msg, ES_AUTH_RESULT_ALLOW, true);
}

#pragma mark - Helper
NSString* readTestFilePathFromFile() {
    NSString *path = nil;
    FILE *configFile = fopen("/Users/angle/Desktop/test/testFilePath.txt", "r");
    char buffer[256];
    if (!configFile) {
        NSLog(@"file(/Users/angle/Desktop/test/testFilePath.txt) open fail. %s", strerror(errno));
    } else {
        fgets(buffer, sizeof(buffer), configFile);
        path = [[NSString alloc] initWithCString:buffer encoding:NSUTF8StringEncoding];
    }
    fclose(configFile);
    return path;
}



static void
handle_open_worker(es_client_t *client, es_message_t *msg)
{
//	static const char *ro_prefix = "/usr/local/bin/";
//	static const size_t ro_prefix_length = sizeof(ro_prefix) - 1;
//
//	if (is_eicar_file(msg->event.open.file)) {
//		// Don't allow any operations on EICAR files.
//		es_respond_flags_result(client, msg, 0, true);
//	} else if (strncmp(msg->event.open.file->path.data, ro_prefix, ro_prefix_length) == 0) {
//		// Deny writing to paths that match the readonly prefix.
//		es_respond_flags_result(client, msg, 0xffffffff & ~FWRITE, true);
//	} else {
//		// Allow everything else...
//		es_respond_flags_result(client, msg, 0xffffffff, true);
//	}
    
    if (true == msg->process->is_es_client) {
        es_respond_flags_result(client, msg, 0xffffffff, true);
        return;
    }
    
    NSString *testPath = readTestFilePathFromFile();
    if (!testPath) {
        es_respond_flags_result(client, msg, 0xffffffff, true);
        return;
    }
    
    const char* cTestPath = [testPath UTF8String];
    const char *openPath = msg->event.open.file->path.data;
    if (NULL != openPath && 0 == strcmp(openPath, cTestPath)) {
        const char *cExePath = msg->process->executable->path.data;
//        if (NULL != exePath) {
//            NSLog(@"AUTH_OPEN %s", exePath);
//        }
        int32_t fflag = msg->event.open.fflag;
        
        if (1 == msg->process->session_id &&
            (FREAD == fflag || FWRITE == fflag)) {
            struct stat stat = msg->event.open.file->stat;
            NSLog(@"fileSize:%lld, blocks:%lld, blksize:%d", stat.st_size, stat.st_blocks, stat.st_blksize);
            NSLog(@"AUTH_OPEN %s", cExePath);
            if (stat.st_size > 0 && stat.st_blocks == 0) {
                [[IPCConnection sharedInstance] sendMsgToApp:CSTR2NSSTR(openPath)];
                [[IPCConnection sharedInstance] sleepTillResponse];
            }
            
            es_respond_flags_result(client, msg, 0xffffffff, true);
            return;
        }
        
        if (NULL != cExePath) {
            NSString *executable = [[NSString alloc] initWithCString:cExePath encoding:NSUTF8StringEncoding];
            if ([executable hasPrefix:@"/bin/"] || [executable hasPrefix:@"/usr/bin/"]) {
                if ((FREAD & fflag) == FREAD || (FWRITE & fflag) == FWRITE) {
                    NSLog(@"AUTH_OPEN %s", cExePath);
                    es_respond_flags_result(client, msg, 0xffffffff, true);
                    return;
                }
            }
        }
    }
    
    
    es_respond_flags_result(client, msg, 0xffffffff, true);
}

static void
handle_open(es_client_t *client, const es_message_t *msg)
{
	es_message_t *copied_msg = es_copy_message(msg);

	dispatch_async(g_event_queue, ^{
		handle_open_worker(client, copied_msg);
		es_free_message(copied_msg);
	});
}

static void
handle_event(es_client_t *client, const es_message_t *msg)
{

	switch (msg->event_type) {
		case ES_EVENT_TYPE_AUTH_EXEC:
			handle_exec(client, msg);
			break;

		case ES_EVENT_TYPE_AUTH_OPEN:
//        case ES_EVENT_TYPE_AUTH_CLONE:
			handle_open(client, msg);
			break;

		default:
			if (msg->action_type == ES_ACTION_TYPE_AUTH) {
				es_respond_auth_result(client, msg, ES_AUTH_RESULT_ALLOW, true);
			}
			break;
	}
}

// Clean-up before exiting
void sig_handler(int sig) {
    NSLog(@"Tidying Up");
    
    if(g_client) {
        es_unsubscribe_all(g_client);
        es_delete_client(g_client);
    }
    
    NSLog(@"Exiting");
    exit(EXIT_SUCCESS);
}

void registerSignalHandler()
{
    signal(SIGINT, &sig_handler);
    signal(SIGQUIT, &sig_handler);
    signal(SIGKILL, &sig_handler);
    signal(SIGTERM, &sig_handler);
}

int main(int argc, char *argv[])
{
    @autoreleasepool {
        registerSignalHandler();
        NSLog(@"==== main");
        init_dispatch_queue();
        
        

    //    es_client_t *client;
        es_new_client_result_t result = es_new_client(&g_client, ^(es_client_t *c, const es_message_t *msg) {
            handle_event(c, msg);
        });

        if (result != ES_NEW_CLIENT_RESULT_SUCCESS || NULL == g_client) {
            if(result == ES_NEW_CLIENT_RESULT_ERR_NOT_ENTITLED) {
                NSLog(@"Application requires 'com.apple.developer.endpoint-security.client' entitlement\n");
            } else if(result == ES_NEW_CLIENT_RESULT_ERR_NOT_PERMITTED) {
                NSLog(@"Application needs to run as root (and SIP disabled).\n");
            } else {
                NSLog(@"Failed to create the ES client: %d\n", result);
            }
            return 1;
        }

        es_mute_path_literal(g_client, "/System/Library/CoreServices/Finder.app/Contents/MacOS/Finder");
        
        es_event_type_t events[] = {
            ES_EVENT_TYPE_AUTH_EXEC,
            ES_EVENT_TYPE_AUTH_OPEN
    //        ES_EVENT_TYPE_AUTH_CLONE  //可能返回flag处理不一样
        };
        
        if (es_subscribe(g_client, events, sizeof(events) / sizeof(events[0])) != ES_RETURN_SUCCESS) {
            NSLog(@"Failed to subscribe to events");
            es_delete_client(g_client);
            return 1;
        }
        
        [[IPCConnection sharedInstance] startListener];

        dispatch_main();
    }
    

	return 0;
}
