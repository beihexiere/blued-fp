#import <UIKit/UIKit.h>
#import <unistd.h>
#import <dispatch/dispatch.h>

#import "BDConfig.h"
#import "BDLocationHook.h"
#import "BDOverlay.h"

__attribute__((constructor)) static void bd_tweak_entry(void) {
    // 构造函数跑在 pre-main 阶段，此时 Flutter 引擎还没初始化。
    // 所有初始化都丢到主队列，等 App 起来之后再执行，避免拖住启动。
    NSLog(@"[BDTweak] dylib loaded, pid=%d", (int)getpid());
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
            NSLog(@"[BDTweak] start install");
            [BDConfig shared];
            [BDLocationHook install];
            [BDOverlay install];
            NSLog(@"[BDTweak] install done");
        }
    });
}
