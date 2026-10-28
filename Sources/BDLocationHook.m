#import "BDLocationHook.h"
#import "BDConfig.h"

#import <CoreLocation/CoreLocation.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#import <dispatch/dispatch.h>
#import <stdlib.h>
#import <string.h>

static NSMutableSet<NSValue *> *gSwizzledClasses = nil;

// 前置声明，供 bd_isOwnHookIMP 比对
static void bd_didUpdateLocations(id self, SEL _cmd, CLLocationManager *manager, NSArray<CLLocation *> *locations);
static void bd_didUpdateToLocation(id self, SEL _cmd, CLLocationManager *manager, CLLocation *newLocation, CLLocation *oldLocation);
static CLLocation *bd_manager_location(id self, SEL _cmd);
static BOOL bd_locationServicesEnabled(id self, SEL _cmd);
static CLAuthorizationStatus bd_authorizationStatus(id self, SEL _cmd);

static void bd_ensureGlobals(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gSwizzledClasses = [NSMutableSet set];
    });
}

/// 该 selector 是否由这个类自己实现（而非从父类继承）
static BOOL bd_classDefinesMethod(Class cls, SEL sel) {
    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    BOOL found = NO;
    for (unsigned int i = 0; i < count; i++) {
        if (sel_isEqual(method_getName(methods[i]), sel)) {
            found = YES;
            break;
        }
    }
    if (methods) {
        free(methods);
    }
    return found;
}

/// 是否是本插件装的 hook 实现
static BOOL bd_isOwnHookIMP(IMP imp) {
    return imp == (IMP)bd_didUpdateLocations || imp == (IMP)bd_didUpdateToLocation ||
           imp == (IMP)bd_manager_location || imp == (IMP)bd_locationServicesEnabled ||
           imp == (IMP)bd_authorizationStatus;
}

/// 沿继承链找"下一层真实实现"：跳过本插件自己的 hook，
/// 这样父子类都实现同一方法时不会互相调用造成无限递归
static IMP bd_nextImplementation(id self, SEL sel) {
    Class cls = object_getClass(self);
    while (cls) {
        if (bd_classDefinesMethod(cls, sel)) {
            IMP imp = method_getImplementation(class_getInstanceMethod(cls, sel));
            if (!bd_isOwnHookIMP(imp)) {
                return imp;
            }
        }
        cls = class_getSuperclass(cls);
    }
    return NULL;
}

/// 把一个实例方法替换成 newIMP
static void bd_replaceInstanceMethod(Class cls, SEL sel, IMP newIMP) {
    if (!cls) {
        return;
    }
    Method method = class_getInstanceMethod(cls, sel);
    if (!method) {
        return;
    }
    const char *types = method_getTypeEncoding(method);

    if (class_addMethod(cls, sel, newIMP, types)) {
        // 原本是继承来的，已在本类上新增了一份实现，父类不受影响
    } else {
        method_setImplementation(class_getInstanceMethod(cls, sel), newIMP);
    }

    [gSwizzledClasses addObject:[NSValue valueWithPointer:(__bridge const void *)cls]];
}

static void bd_replaceClassMethod(Class cls, SEL sel, IMP newIMP) {
    bd_replaceInstanceMethod(object_getClass(cls), sel, newIMP);
}

#pragma mark - Hook 实现

static void bd_didUpdateLocations(id self, SEL _cmd, CLLocationManager *manager, NSArray<CLLocation *> *locations) {
    BDConfig *config = [BDConfig shared];
    if (config.fakeLocationEnabled) {
        locations = @[ [config fakeLocation] ];
    }
    IMP original = bd_nextImplementation(self, _cmd);
    if (original) {
        ((void (*)(id, SEL, CLLocationManager *, NSArray *))original)(self, _cmd, manager, locations);
    }
}

static void bd_didUpdateToLocation(id self, SEL _cmd, CLLocationManager *manager, CLLocation *newLocation, CLLocation *oldLocation) {
    BDConfig *config = [BDConfig shared];
    if (config.fakeLocationEnabled) {
        newLocation = [config fakeLocation];
    }
    IMP original = bd_nextImplementation(self, _cmd);
    if (original) {
        ((void (*)(id, SEL, CLLocationManager *, CLLocation *, CLLocation *))original)(self, _cmd, manager, newLocation, oldLocation);
    }
}

static CLLocation *bd_manager_location(id self, SEL _cmd) {
    BDConfig *config = [BDConfig shared];
    if (config.fakeLocationEnabled) {
        return [config fakeLocation];
    }
    IMP original = bd_nextImplementation(self, _cmd);
    return original ? ((CLLocation * (*)(id, SEL))original)(self, _cmd) : nil;
}

static BOOL bd_locationServicesEnabled(id self, SEL _cmd) {
    if ([BDConfig shared].fakeLocationEnabled) {
        return YES;
    }
    IMP original = bd_nextImplementation(self, _cmd);
    return original ? ((BOOL(*)(id, SEL))original)(self, _cmd) : YES;
}

static CLAuthorizationStatus bd_authorizationStatus(id self, SEL _cmd) {
    if ([BDConfig shared].fakeLocationEnabled) {
        return kCLAuthorizationStatusAuthorizedWhenInUse;
    }
    IMP original = bd_nextImplementation(self, _cmd);
    return original ? ((CLAuthorizationStatus(*)(id, SEL))original)(self, _cmd) : kCLAuthorizationStatusNotDetermined;
}

#pragma mark - 扫描所有实现定位代理方法的类

static void bd_scanClasses(void) {
    bd_ensureGlobals();

    int count = objc_getClassList(NULL, 0);
    if (count <= 0) {
        return;
    }
    Class *classes = (Class *)malloc(sizeof(Class) * (size_t)count);
    if (!classes) {
        return;
    }
    count = objc_getClassList(classes, count);

    SEL didUpdateLocations = @selector(locationManager:didUpdateLocations:);
    SEL didUpdateToLocation = @selector(locationManager:didUpdateToLocation:fromLocation:);

    for (int i = 0; i < count; i++) {
        Class cls = classes[i];
        if (!cls) {
            continue;
        }
        const char *name = class_getName(cls);
        if (!name || strncmp(name, "BD", 2) == 0) {
            continue;
        }
        NSValue *key = [NSValue valueWithPointer:(__bridge const void *)cls];
        if ([gSwizzledClasses containsObject:key]) {
            continue;
        }
        if (bd_classDefinesMethod(cls, didUpdateLocations)) {
            bd_replaceInstanceMethod(cls, didUpdateLocations, (IMP)bd_didUpdateLocations);
        }
        if (bd_classDefinesMethod(cls, didUpdateToLocation)) {
            bd_replaceInstanceMethod(cls, didUpdateToLocation, (IMP)bd_didUpdateToLocation);
        }
    }

    free(classes);
}

static void bd_image_added(const struct mach_header *header, intptr_t slide) {
    // 该回调在 dyld 加锁期间触发，丢到主队列执行，避免和运行时锁互相等待
    dispatch_async(dispatch_get_main_queue(), ^{
        bd_scanClasses();
    });
}

#pragma mark -

@implementation BDLocationHook

+ (void)install {
    bd_ensureGlobals();
    bd_scanClasses();

    Class managerClass = [CLLocationManager class];
    bd_replaceInstanceMethod(managerClass, @selector(location), (IMP)bd_manager_location);
    bd_replaceClassMethod(managerClass, @selector(locationServicesEnabled), (IMP)bd_locationServicesEnabled);
    bd_replaceClassMethod(managerClass, @selector(authorizationStatus), (IMP)bd_authorizationStatus);

    // 后续动态加载的镜像（Flutter 插件、地图 SDK 等）加载时补扫一次
    _dyld_register_func_for_add_image(bd_image_added);

    NSLog(@"[BDTweak] location hooks installed");
}

@end
