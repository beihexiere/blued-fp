#import <Foundation/Foundation.h>

@interface BDLocationHook : NSObject

/// 安装定位相关 hook。全程只做 ObjC 方法替换，不依赖 CydiaSubstrate。
+ (void)install;

@end
