#import <Foundation/Foundation.h>

@interface BDOverlay : NSObject

/// 在 App 窗口上挂悬浮球（幂等，可重复调用）
+ (void)install;

/// 配置变化后刷新显示
+ (void)refresh;

@end
