#import "BDOverlay.h"
#import "BDConfig.h"

#import <UIKit/UIKit.h>

static const CGFloat kButtonSize = 46.0;
static NSString *const kButtonXKey = @"BDHook.buttonX";
static NSString *const kButtonYKey = @"BDHook.buttonY";

#pragma mark - 工具函数

static UIWindow *bd_keyWindow(void) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) {
            continue;
        }
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.isKeyWindow) {
                return window;
            }
        }
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    for (UIWindow *window in UIApplication.sharedApplication.windows) {
        if (window.isKeyWindow) {
            return window;
        }
    }
    return UIApplication.sharedApplication.windows.firstObject;
#pragma clang diagnostic pop
}

static UIViewController *bd_topViewController(UIViewController *root) {
    UIViewController *vc = root;
    while (vc.presentedViewController && !vc.presentedViewController.isBeingDismissed) {
        vc = vc.presentedViewController;
    }
    if ([vc isKindOfClass:[UINavigationController class]]) {
        UIViewController *top = ((UINavigationController *)vc).topViewController;
        return top ? bd_topViewController(top) : vc;
    }
    if ([vc isKindOfClass:[UITabBarController class]]) {
        UIViewController *selected = ((UITabBarController *)vc).selectedViewController;
        return selected ? bd_topViewController(selected) : vc;
    }
    return vc;
}

#pragma mark - 设置面板

@interface BDSettingsViewController : UIViewController
@end

@implementation BDSettingsViewController {
    UISwitch *_locationSwitch;
    UISwitch *_buttonSwitch;
    UITextField *_latitudeField;
    UITextField *_longitudeField;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Blued 插件";
    self.view.backgroundColor = [UIColor colorWithWhite:0.09 alpha:1.0];
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;

    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"取消" style:UIBarButtonItemStylePlain target:self action:@selector(onCancel)];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"保存" style:UIBarButtonItemStyleDone target:self action:@selector(onSave)];

    BDConfig *config = [BDConfig shared];

    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:scrollView];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 10.0;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [scrollView addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [stack.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor constant:16.0],
        [stack.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor constant:-16.0],
        [stack.leadingAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.leadingAnchor constant:16.0],
        [stack.trailingAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.trailingAnchor constant:-16.0],
    ]];

    [stack addArrangedSubview:[self sectionLabel:@"定位"]];

    _locationSwitch = [[UISwitch alloc] init];
    _locationSwitch.on = config.fakeLocationEnabled;
    [stack addArrangedSubview:[self rowWithTitle:@"启用虚拟定位" accessory:_locationSwitch]];

    _latitudeField = [self fieldWithText:[NSString stringWithFormat:@"%.6f", config.latitude]];
    [stack addArrangedSubview:[self rowWithTitle:@"纬度" accessory:_latitudeField]];

    _longitudeField = [self fieldWithText:[NSString stringWithFormat:@"%.6f", config.longitude]];
    [stack addArrangedSubview:[self rowWithTitle:@"经度" accessory:_longitudeField]];

    [stack addArrangedSubview:[self sectionLabel:@"界面"]];

    _buttonSwitch = [[UISwitch alloc] init];
    _buttonSwitch.on = config.showFloatingButton;
    [stack addArrangedSubview:[self rowWithTitle:@"显示悬浮球" accessory:_buttonSwitch]];

    [stack addArrangedSubview:[self hintLabel:@"关闭后悬浮球会缩成半透明小圆点，点击小圆点仍可重新打开本面板。"]];

    [stack addArrangedSubview:[self sectionLabel:@"说明"]];

    [stack addArrangedSubview:[self hintLabel:@"虚拟定位作用于 App 进程内的 CoreLocation：地图、附近列表等走原生定位的页面会生效。客户端 hook 无法绕过服务端校验。"]];
}

- (UIView *)sectionLabel:(NSString *)text {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
    label.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [label.heightAnchor constraintEqualToConstant:24.0].active = YES;
    return label;
}

- (UIView *)hintLabel:(NSString *)text {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.numberOfLines = 0;
    label.font = [UIFont systemFontOfSize:12.0];
    label.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
    return label;
}

- (UIView *)rowWithTitle:(NSString *)title accessory:(UIView *)accessory {
    UIView *row = [[UIView alloc] init];
    row.backgroundColor = [UIColor colorWithWhite:0.16 alpha:1.0];
    row.layer.cornerRadius = 10.0;
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [row.heightAnchor constraintEqualToConstant:50.0].active = YES;

    UILabel *label = [[UILabel alloc] init];
    label.text = title;
    label.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium];
    label.textColor = [UIColor colorWithWhite:0.94 alpha:1.0];
    [label setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];

    UIStackView *content = [[UIStackView alloc] initWithArrangedSubviews:@[ label, accessory ]];
    content.axis = UILayoutConstraintAxisHorizontal;
    content.alignment = UIStackViewAlignmentCenter;
    content.spacing = 12.0;
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:content];

    [NSLayoutConstraint activateConstraints:@[
        [content.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:14.0],
        [content.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-14.0],
        [content.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
    ]];
    return row;
}

- (UITextField *)fieldWithText:(NSString *)text {
    UITextField *field = [[UITextField alloc] init];
    field.text = text;
    field.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    field.textAlignment = NSTextAlignmentRight;
    field.textColor = [UIColor whiteColor];
    field.font = [UIFont monospacedDigitSystemFontOfSize:15.0 weight:UIFontWeightRegular];
    field.clearButtonMode = UITextFieldViewModeWhileEditing;
    field.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"0.000000"
                                                                 attributes:@{NSForegroundColorAttributeName : [UIColor colorWithWhite:0.5 alpha:1.0]}];
    [field.widthAnchor constraintGreaterThanOrEqualToConstant:140.0].active = YES;
    return field;
}

- (void)onCancel {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)onSave {
    BDConfig *config = [BDConfig shared];

    double latitude = [_latitudeField.text doubleValue];
    double longitude = [_longitudeField.text doubleValue];
    if (latitude < -90.0 || latitude > 90.0) {
        latitude = config.latitude;
    }
    if (longitude < -180.0 || longitude > 180.0) {
        longitude = config.longitude;
    }

    config.fakeLocationEnabled = _locationSwitch.isOn;
    config.showFloatingButton = _buttonSwitch.isOn;
    config.latitude = latitude;
    config.longitude = longitude;
    [config save];

    [BDOverlay refresh];
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

#pragma mark - 悬浮球

@interface BDOverlay ()

@property (nonatomic, strong) UIButton *button;

- (void)attach;

@end

@implementation BDOverlay

+ (instancetype)shared {
    static BDOverlay *instance = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [[BDOverlay alloc] init];
    });
    return instance;
}

+ (void)install {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
                                                          [[BDOverlay shared] attach];
                                                      }];
    });
    [[BDOverlay shared] attach];
}

+ (void)refresh {
    [[BDOverlay shared] attach];
}

- (void)attach {
    UIWindow *window = bd_keyWindow();
    if (!window) {
        return;
    }

    if (!self.button) {
        self.button = [self buildButton];
    }

    BOOL expanded = [BDConfig shared].showFloatingButton;
    CGFloat size = expanded ? kButtonSize : 20.0;
    self.button.bounds = CGRectMake(0.0, 0.0, size, size);
    self.button.layer.cornerRadius = size / 2.0;
    self.button.alpha = expanded ? 0.92 : 0.25;
    [self.button setImage:(expanded ? [UIImage systemImageNamed:@"gearshape.fill"] : nil) forState:UIControlStateNormal];

    if (self.button.superview != window) {
        [self.button removeFromSuperview];
        [window addSubview:self.button];
        self.button.center = [self restoredCenterInWindow:window];
    }
    [window bringSubviewToFront:self.button];
}

- (UIButton *)buildButton {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
    button.tintColor = [UIColor whiteColor];
    button.imageView.contentMode = UIViewContentModeScaleAspectFit;
    button.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    button.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.25].CGColor;
    [button addTarget:self action:@selector(onTap) forControlEvents:UIControlEventTouchUpInside];
    [button addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onPan:)]];
    return button;
}

- (CGPoint)restoredCenterInWindow:(UIWindow *)window {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    CGFloat x = [defaults doubleForKey:kButtonXKey];
    CGFloat y = [defaults doubleForKey:kButtonYKey];
    if (x <= 0.0 || y <= 0.0) {
        x = window.bounds.size.width - 34.0;
        y = window.bounds.size.height * 0.35;
    }
    return [self clampedCenter:CGPointMake(x, y) inWindow:window];
}

- (CGPoint)clampedCenter:(CGPoint)center inWindow:(UIWindow *)window {
    CGFloat half = MAX(self.button.bounds.size.width, self.button.bounds.size.height) / 2.0;
    CGFloat x = MIN(MAX(center.x, half + 4.0), MAX(window.bounds.size.width - half - 4.0, half + 4.0));
    CGFloat y = MIN(MAX(center.y, half + 60.0), MAX(window.bounds.size.height - half - 40.0, half + 60.0));
    return CGPointMake(x, y);
}

- (void)onPan:(UIPanGestureRecognizer *)gesture {
    UIView *host = self.button.superview;
    if (!host) {
        return;
    }
    CGPoint translation = [gesture translationInView:host];
    self.button.center = CGPointMake(self.button.center.x + translation.x, self.button.center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:host];

    if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        CGPoint center = [self clampedCenter:self.button.center inWindow:(UIWindow *)host];
        CGFloat half = self.button.bounds.size.width / 2.0;
        BOOL atEdge = (center.x <= half + 8.0) || (center.x >= host.bounds.size.width - half - 8.0);
        if (atEdge) {
            center.x = (center.x < host.bounds.size.width / 2.0) ? half + 4.0 : host.bounds.size.width - half - 4.0;
        }
        self.button.center = center;
        self.button.alpha = atEdge ? 0.35 : ([BDConfig shared].showFloatingButton ? 0.92 : 0.25);

        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setDouble:center.x forKey:kButtonXKey];
        [defaults setDouble:center.y forKey:kButtonYKey];
        [defaults synchronize];
    }
}

- (void)onTap {
    UIWindow *window = bd_keyWindow();
    UIViewController *top = bd_topViewController(window.rootViewController);
    if (!top) {
        return;
    }
    if ([top isKindOfClass:[UINavigationController class]] &&
        [((UINavigationController *)top).topViewController isKindOfClass:[BDSettingsViewController class]]) {
        return;
    }

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:[[BDSettingsViewController alloc] init]];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [top presentViewController:nav animated:YES completion:nil];
}

@end
