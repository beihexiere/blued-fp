#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

/// 插件配置，持久化在 NSUserDefaults（随 App 沙盒，重装失效）
@interface BDConfig : NSObject

+ (instancetype)shared;

@property (nonatomic) BOOL fakeLocationEnabled;
@property (nonatomic) BOOL showFloatingButton;
@property (nonatomic) double latitude;
@property (nonatomic) double longitude;

/// 由当前经纬度生成的伪造坐标对象
- (CLLocation *)fakeLocation;

- (void)reload;
- (void)save;

@end

NS_ASSUME_NONNULL_END
