#import "BDConfig.h"

static NSString *const kFakeEnabled = @"BDHook.fakeLocationEnabled";
static NSString *const kShowButton = @"BDHook.showFloatingButton";
static NSString *const kLatitude = @"BDHook.latitude";
static NSString *const kLongitude = @"BDHook.longitude";

@implementation BDConfig

+ (instancetype)shared {
    static BDConfig *instance = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [[BDConfig alloc] init];
        [instance reload];
    });
    return instance;
}

- (void)reload {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:@{
        kFakeEnabled : @NO,
        kShowButton : @YES,
        kLatitude : @39.908722,
        kLongitude : @116.397499,
    }];
    _fakeLocationEnabled = [defaults boolForKey:kFakeEnabled];
    _showFloatingButton = [defaults boolForKey:kShowButton];
    _latitude = [defaults doubleForKey:kLatitude];
    _longitude = [defaults doubleForKey:kLongitude];
}

- (void)save {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:self.fakeLocationEnabled forKey:kFakeEnabled];
    [defaults setBool:self.showFloatingButton forKey:kShowButton];
    [defaults setDouble:self.latitude forKey:kLatitude];
    [defaults setDouble:self.longitude forKey:kLongitude];
    [defaults synchronize];
}

- (CLLocation *)fakeLocation {
    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(self.latitude, self.longitude);
    return [[CLLocation alloc] initWithCoordinate:coordinate
                                         altitude:20.0
                               horizontalAccuracy:10.0
                                 verticalAccuracy:10.0
                                        timestamp:[NSDate date]];
}

@end
