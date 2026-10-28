#import <UIKit/UIKit.h>
#import <unistd.h>
#import <dispatch/dispatch.h>

#import "BDConfig.h"
#import "BDLocationHook.h"
#import "BDOverlay.h"

__attribute__((constructor)) static void bd_hook_entry(void) {
    @autoreleasepool {
        NSLog(@"[BDHook] dylib loaded, pid=%d", (int)getpid());
        [BDConfig shared];
        [BDLocationHook install];
        dispatch_async(dispatch_get_main_queue(), ^{
            [BDOverlay install];
        });
    }
}
