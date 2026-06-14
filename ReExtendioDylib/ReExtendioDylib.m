#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

struct __float2 { float __sinval; float __cosval; };
struct __double2 { double __sinval; double __cosval; };

typedef void (^REURLSessionDataCompletion)(NSData *data, NSURLResponse *response, NSError *error);


static NSString *REStringFromObject(id value) {
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

static NSString *REPercentDecode(NSString *value) {
    return value ? [value stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] : nil;
}

static NSString *REPercentEncode(NSString *value) {
    return value ? [value stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] : nil;
}

NSString * const NSURLSessionDownloadTaskResumeData = @"NSURLSessionDownloadTaskResumeData";
const int64_t NSURLSessionTransferSizeUnknown = -1;

// iOS 7/8/9-only string constants absent from iOS 6. Apps and nested
// frameworks (e.g. XSAPITCUI) that link them resolve from this shim; everything
// else falls through to the real frameworks via reexport.
NSString * const NSLinkAttributeName = @"NSLink";
NSString * const UIFontTextStyleBody = @"UICTFontTextStyleBody";
NSString * const UIFontTextStyleHeadline = @"UICTFontTextStyleHeadline";
NSString * const UIFontTextStyleSubheadline = @"UICTFontTextStyleSubhead";
NSString * const UIFontTextStyleFootnote = @"UICTFontTextStyleFootnote";
NSString * const UIFontTextStyleCaption1 = @"UICTFontTextStyleCaption1";
NSString * const UIFontTextStyleCaption2 = @"UICTFontTextStyleCaption2";
NSString * const UIContentSizeCategoryDidChangeNotification = @"UIContentSizeCategoryDidChangeNotification";
NSString * const UIApplicationOpenSettingsURLString = @"app-settings:";
NSString * const UIApplicationOpenURLOptionsSourceApplicationKey = @"UIApplicationOpenURLOptionsSourceApplicationKey";

@implementation NSURLQueryItem

+ (instancetype)queryItemWithName:(NSString *)name value:(NSString *)value {
    return [[self alloc] initWithName:name value:value];
}

- (instancetype)initWithName:(NSString *)name value:(NSString *)value {
    self = [super init];
    if (self) {
        _name = [name copy];
        _value = [value copy];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    return [[[self class] allocWithZone:zone] initWithName:self.name value:self.value];
}

@end

@interface NSURLComponents ()
@property(nonatomic, copy) NSString *rawString;
@end

@implementation NSURLComponents

- (instancetype)init {
    return [self initWithString:nil];
}

- (instancetype)initWithString:(NSString *)URLString {
    self = [super init];
    if (self) {
        _rawString = [URLString copy];
        if (URLString.length) {
            NSURL *url = [NSURL URLWithString:URLString];
            [self reinitializeFromURL:url resolvingAgainstBaseURL:NO];
        }
    }
    return self;
}

- (instancetype)initWithURL:(NSURL *)url resolvingAgainstBaseURL:(BOOL)resolve {
    self = [super init];
    if (self) {
        [self reinitializeFromURL:url resolvingAgainstBaseURL:resolve];
    }
    return self;
}

+ (instancetype)componentsWithURL:(NSURL *)url resolvingAgainstBaseURL:(BOOL)resolve {
    return [[self alloc] initWithURL:url resolvingAgainstBaseURL:resolve];
}

+ (instancetype)componentsWithString:(NSString *)URLString {
    return [[self alloc] initWithString:URLString];
}

- (void)reinitializeFromURL:(NSURL *)url resolvingAgainstBaseURL:(BOOL)resolve {
    if (!url) {
        return;
    }
    if (resolve) {
        url = [url absoluteURL];
    }
    self.scheme = REStringFromObject([url scheme]);
    self.user = REStringFromObject([url user]);
    self.password = REStringFromObject([url password]);
    self.host = REStringFromObject([url host]);
    self.port = [url port];
    self.path = REStringFromObject([url path]);
    self.query = REStringFromObject([url query]);
    self.fragment = REStringFromObject([url fragment]);
    self.percentEncodedUser = self.user;
    self.percentEncodedPassword = self.password;
    self.percentEncodedHost = self.host;
    self.percentEncodedPath = self.path;
    self.percentEncodedQuery = self.query;
    self.percentEncodedFragment = self.fragment;
    [self syncQueryItemsFromQuery];
}

- (void)syncQueryItemsFromQuery {
    if (self.query.length == 0) {
        self.queryItems = self.query ? @[] : nil;
        return;
    }
    NSMutableArray *items = [NSMutableArray array];
    for (NSString *pair in [self.query componentsSeparatedByString:@"&"]) {
        if (pair.length == 0) {
            [items addObject:[[NSURLQueryItem alloc] initWithName:@"" value:nil]];
            continue;
        }
        NSRange eq = [pair rangeOfString:@"="];
        if (eq.location == NSNotFound) {
            [items addObject:[[NSURLQueryItem alloc] initWithName:REPercentDecode(pair) value:nil]];
        } else {
            NSString *name = [pair substringToIndex:eq.location];
            NSString *value = [pair substringFromIndex:eq.location + 1];
            [items addObject:[[NSURLQueryItem alloc] initWithName:REPercentDecode(name) value:REPercentDecode(value)]];
        }
    }
    _queryItems = [items copy];
}

- (void)setQueryItems:(NSArray *)queryItems {
    _queryItems = [queryItems copy];
    if (queryItems == nil) {
        self.query = nil;
        self.percentEncodedQuery = nil;
        return;
    }
    NSMutableArray *pairs = [NSMutableArray array];
    for (id item in queryItems) {
        NSString *name = REStringFromObject([item valueForKey:@"name"]);
        NSString *value = REStringFromObject([item valueForKey:@"value"]);
        if (!name) {
            name = @"";
        }
        if (value) {
            [pairs addObject:[NSString stringWithFormat:@"%@=%@", REPercentEncode(name), REPercentEncode(value)]];
        } else {
            [pairs addObject:REPercentEncode(name) ?: @""];
        }
    }
    self.query = [pairs componentsJoinedByString:@"&"];
    self.percentEncodedQuery = self.query;
}

- (NSString *)string {
    if (self.rawString.length && self.scheme == nil && self.host == nil && self.path == nil && self.query == nil && self.fragment == nil) {
        return self.rawString;
    }
    NSMutableString *result = [NSMutableString string];
    if (self.scheme.length) {
        [result appendFormat:@"%@:", self.scheme];
    }
    BOOL hasAuthority = self.user.length || self.password.length || self.host.length || self.port != nil;
    if (hasAuthority) {
        [result appendString:@"//"];
        if (self.user.length) {
            [result appendString:REPercentEncode(self.user) ?: @""];
            if (self.password.length) {
                [result appendFormat:@":%@", REPercentEncode(self.password) ?: @""];
            }
            [result appendString:@"@"]; 
        }
        if (self.host.length) {
            [result appendString:self.host];
        }
        if (self.port != nil) {
            [result appendFormat:@":%@", self.port];
        }
    }
    if (self.path.length) {
        if (hasAuthority && ![self.path hasPrefix:@"/"]) {
            [result appendString:@"/"];
        }
        [result appendString:self.path];
    } else if (hasAuthority) {
        [result appendString:@"/"];
    }
    if (self.query.length) {
        [result appendFormat:@"?%@", self.query];
    }
    if (self.fragment.length) {
        [result appendFormat:@"#%@", self.fragment];
    }
    return result;
}

- (NSURL *)URL {
    return [NSURL URLWithString:self.string];
}

- (NSURL *)URLRelativeToURL:(NSURL *)baseURL {
    return baseURL ? [NSURL URLWithString:self.string relativeToURL:baseURL] : [NSURL URLWithString:self.string];
}

- (id)copyWithZone:(NSZone *)zone {
    NSURLComponents *copy = [[[self class] allocWithZone:zone] init];
    copy.scheme = self.scheme;
    copy.user = self.user;
    copy.password = self.password;
    copy.host = self.host;
    copy.port = self.port;
    copy.path = self.path;
    copy.query = self.query;
    copy.fragment = self.fragment;
    copy.percentEncodedUser = self.percentEncodedUser;
    copy.percentEncodedPassword = self.percentEncodedPassword;
    copy.percentEncodedHost = self.percentEncodedHost;
    copy.percentEncodedPath = self.percentEncodedPath;
    copy.percentEncodedQuery = self.percentEncodedQuery;
    copy.percentEncodedFragment = self.percentEncodedFragment;
    copy.queryItems = self.queryItems;
    copy.rawString = self.rawString;
    return copy;
}

@end

@interface NSURLSessionTask () {
    NSUInteger _re_taskIdentifier;
    NSURLRequest *_re_originalRequest;
    NSURLRequest *_re_currentRequest;
    NSURLResponse *_re_response;
    NSURLSessionTaskState _re_state;
}
- (void)re_setOriginalRequest:(NSURLRequest *)request;
- (void)re_setCurrentRequest:(NSURLRequest *)request;
- (void)re_setResponse:(NSURLResponse *)response;
- (void)re_finish;
@end

@implementation NSURLSessionTask

+ (NSUInteger)re_nextTaskIdentifier {
    static NSUInteger nextTaskIdentifier = 0;
    @synchronized(self) {
        return ++nextTaskIdentifier;
    }
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _re_taskIdentifier = [[self class] re_nextTaskIdentifier];
        _re_state = NSURLSessionTaskStateSuspended;
    }
    return self;
}

- (void)re_setOriginalRequest:(NSURLRequest *)request {
    _re_originalRequest = request;
    _re_currentRequest = request;
}

- (void)re_setCurrentRequest:(NSURLRequest *)request {
    _re_currentRequest = request;
}

- (void)re_setResponse:(NSURLResponse *)response {
    _re_response = response;
}

- (void)re_finish {
    _re_state = NSURLSessionTaskStateCompleted;
}

- (NSUInteger)taskIdentifier {
    return _re_taskIdentifier;
}

- (NSURLRequest *)originalRequest {
    return _re_originalRequest;
}

- (NSURLRequest *)currentRequest {
    return _re_currentRequest;
}

- (NSURLResponse *)response {
    return _re_response;
}

- (NSURLSessionTaskState)state {
    return _re_state;
}

- (void)resume {
    _re_state = NSURLSessionTaskStateRunning;
}

- (void)suspend {
    _re_state = NSURLSessionTaskStateSuspended;
}

- (void)cancel {
    _re_state = NSURLSessionTaskStateCanceling;
    _re_state = NSURLSessionTaskStateCompleted;
}

@end

@interface NSURLSessionDataTask () {
    REURLSessionDataCompletion _re_completionHandler;
    BOOL _re_completionDelivered;
}
- (void)re_setCompletionHandler:(REURLSessionDataCompletion)completionHandler;
@end

@implementation NSURLSessionDataTask

- (void)re_setCompletionHandler:(REURLSessionDataCompletion)completionHandler {
    _re_completionHandler = [completionHandler copy];
}

- (void)resume {
    [super resume];
    if (_re_completionDelivered || !_re_completionHandler) {
        return;
    }
    _re_completionDelivered = YES;
    NSURL *url = self.currentRequest.URL ?: [NSURL URLWithString:@"about:blank"];
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{}];
    _re_completionHandler([NSData data], response, nil);
    [self re_finish];
}

@end

@interface NSURLSessionDownloadTask ()
@end

@implementation NSURLSessionDownloadTask

- (void)cancelByProducingResumeData:(void (^)(NSData *resumeData))completionHandler {
    if (completionHandler) {
        completionHandler([NSData data]);
    }
    [self cancel];
}

@end

@implementation NSURLSessionUploadTask
@end

@implementation NSURLSessionStreamTask
@end

@interface NSURLSession () {
    NSURLSessionConfiguration *_re_configuration;
    id _re_delegate;
    NSOperationQueue *_re_delegateQueue;
}
- (void)re_setConfiguration:(NSURLSessionConfiguration *)configuration delegate:(id)delegate delegateQueue:(NSOperationQueue *)queue;
@end

@implementation NSURLSession

- (void)re_setConfiguration:(NSURLSessionConfiguration *)configuration delegate:(id)delegate delegateQueue:(NSOperationQueue *)queue {
    _re_configuration = configuration;
    _re_delegate = delegate;
    _re_delegateQueue = queue;
}

+ (instancetype)sharedSession {
    return [self sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
}

+ (instancetype)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration {
    return [self sessionWithConfiguration:configuration delegate:nil delegateQueue:nil];
}

+ (instancetype)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration delegate:(id)delegate delegateQueue:(NSOperationQueue *)queue {
    NSURLSession *session = [[self alloc] init];
    [session re_setConfiguration:configuration delegate:delegate delegateQueue:queue];
    return session;
}

- (void)finishTasksAndInvalidate {
}

- (void)invalidateAndCancel {
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request {
    NSURLSessionDataTask *task = [NSURLSessionDataTask new];
    [task re_setOriginalRequest:request];
    return task;
}

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url {
    return [self dataTaskWithRequest:[NSURLRequest requestWithURL:url]];
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    NSURLSessionDataTask *task = [NSURLSessionDataTask new];
    [task re_setOriginalRequest:request];
    [task re_setCompletionHandler:completionHandler];
    return task;
}

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    return [self dataTaskWithRequest:[NSURLRequest requestWithURL:url] completionHandler:completionHandler];
}

- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromData:(NSData *)bodyData {
    NSURLSessionUploadTask *task = [NSURLSessionUploadTask new];
    [task re_setOriginalRequest:request];
    return task;
}

- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromFile:(NSURL *)fileURL {
    NSURLSessionUploadTask *task = [NSURLSessionUploadTask new];
    [task re_setOriginalRequest:request];
    return task;
}

- (NSURLSessionUploadTask *)uploadTaskWithStreamedRequest:(NSURLRequest *)request {
    NSURLSessionUploadTask *task = [NSURLSessionUploadTask new];
    [task re_setOriginalRequest:request];
    return task;
}

- (NSURLSessionDownloadTask *)downloadTaskWithRequest:(NSURLRequest *)request {
    NSURLSessionDownloadTask *task = [NSURLSessionDownloadTask new];
    [task re_setOriginalRequest:request];
    return task;
}

- (NSURLSessionDownloadTask *)downloadTaskWithURL:(NSURL *)url {
    return [self downloadTaskWithRequest:[NSURLRequest requestWithURL:url]];
}

- (NSURLSessionDownloadTask *)downloadTaskWithResumeData:(NSData *)resumeData {
    NSURLSessionDownloadTask *task = [NSURLSessionDownloadTask new];
    return task;
}

- (NSURLSessionStreamTask *)streamTaskWithHostName:(NSString *)hostname port:(NSInteger)port {
    NSURLSessionStreamTask *task = [NSURLSessionStreamTask new];
    return task;
}

- (NSURLSessionStreamTask *)streamTaskWithNetService:(NSNetService *)service {
    NSURLSessionStreamTask *task = [NSURLSessionStreamTask new];
    return task;
}

@end

@implementation NSURLSessionConfiguration

+ (instancetype)defaultSessionConfiguration {
    return [self new];
}

+ (instancetype)ephemeralSessionConfiguration {
    return [self new];
}

+ (instancetype)backgroundSessionConfigurationWithIdentifier:(NSString *)identifier {
    return [self new];
}

- (id)copyWithZone:(NSZone *)zone {
    return [[[self class] allocWithZone:zone] init];
}

@end

#pragma mark - NSProgress (iOS 7)

@interface NSProgress ()
@property(nonatomic) int64_t re_totalUnitCount;
@property(nonatomic) int64_t re_completedUnitCount;
@end

@implementation NSProgress

+ (NSProgress *)progressWithTotalUnitCount:(int64_t)unitCount {
    NSProgress *p = [[self alloc] init];
    p.re_totalUnitCount = unitCount;
    return p;
}

+ (NSProgress *)currentProgress {
    return nil;
}

- (instancetype)initWithParent:(NSProgress *)parent userInfo:(NSDictionary *)userInfo {
    return [super init];
}

- (void)becomeCurrentWithPendingUnitCount:(int64_t)unitCount {}
- (void)resignCurrent {}

- (int64_t)totalUnitCount { return self.re_totalUnitCount; }
- (void)setTotalUnitCount:(int64_t)v { self.re_totalUnitCount = v; }
- (int64_t)completedUnitCount { return self.re_completedUnitCount; }
- (void)setCompletedUnitCount:(int64_t)v { self.re_completedUnitCount = v; }

- (double)fractionCompleted {
    if (self.re_totalUnitCount <= 0) {
        return 0.0;
    }
    return (double)self.re_completedUnitCount / (double)self.re_totalUnitCount;
}

- (BOOL)isCancelled { return NO; }
- (void)cancel {}

@end

#pragma mark - UIAlertAction / UIAlertController (iOS 8)

@interface UIAlertAction ()
@property(nonatomic, copy, readwrite) NSString *title;
@property(nonatomic, readwrite) UIAlertActionStyle style;
@property(nonatomic, copy) void (^re_handler)(UIAlertAction *action);
@end

@implementation UIAlertAction

+ (instancetype)actionWithTitle:(NSString *)title style:(UIAlertActionStyle)style handler:(void (^)(UIAlertAction *action))handler {
    UIAlertAction *action = [[self alloc] init];
    action.title = title;
    action.style = style;
    action.re_handler = handler;
    return action;
}

@end

@interface UIAlertController () <UIAlertViewDelegate> {
    NSString *_re_title;
    NSString *_re_message;
    UIAlertControllerStyle _re_preferredStyle;
}
@property(nonatomic, strong) NSMutableArray *re_actions;
@end

@implementation UIAlertController

+ (instancetype)alertControllerWithTitle:(NSString *)title message:(NSString *)message preferredStyle:(UIAlertControllerStyle)preferredStyle {
    UIAlertController *controller = [[self alloc] init];
    controller->_re_title = [title copy];
    controller->_re_message = [message copy];
    controller->_re_preferredStyle = preferredStyle;
    controller.re_actions = [NSMutableArray array];
    return controller;
}

- (NSString *)title { return _re_title; }
- (void)setTitle:(NSString *)title { _re_title = [title copy]; }
- (NSString *)message { return _re_message; }
- (UIAlertControllerStyle)preferredStyle { return _re_preferredStyle; }

- (void)addAction:(UIAlertAction *)action {
    if (action) {
        [self.re_actions addObject:action];
    }
}

- (NSArray *)actions {
    return [self.re_actions copy];
}

// On iOS 6 there is no presentViewController:animated:completion: for alert-style
// controllers in the iOS 8 sense, so fall back to a classic UIAlertView when the
// app tries to present us as a view controller.
- (void)re_presentAsAlertView {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:self.title
                                                    message:self.message
                                                   delegate:self
                                          cancelButtonTitle:nil
                                          otherButtonTitles:nil];
    if (self.re_actions.count == 0) {
        [alert addButtonWithTitle:@"OK"];
    } else {
        for (UIAlertAction *action in self.re_actions) {
            [alert addButtonWithTitle:action.title ?: @""];
        }
    }
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex >= 0 && (NSUInteger)buttonIndex < self.re_actions.count) {
        UIAlertAction *action = self.re_actions[buttonIndex];
        if (action.re_handler) {
            action.re_handler(action);
        }
    }
}

@end

#pragma mark - UIUserNotificationSettings (iOS 8)

@interface UIUserNotificationSettings () {
    UIUserNotificationType _re_types;
}
@end

@implementation UIUserNotificationSettings

+ (instancetype)settingsForTypes:(UIUserNotificationType)types categories:(NSSet *)categories {
    UIUserNotificationSettings *settings = [[self alloc] init];
    settings->_re_types = types;
    return settings;
}

- (UIUserNotificationType)types {
    return _re_types;
}

@end

#pragma mark - AVSpeechUtterance / AVSpeechSynthesizer (iOS 7)

@interface AVSpeechUtterance ()
@property(nonatomic, copy, readwrite) NSString *speechString;
@end

@implementation AVSpeechUtterance

+ (instancetype)speechUtteranceWithString:(NSString *)string {
    AVSpeechUtterance *utterance = [[self alloc] init];
    utterance.speechString = string;
    return utterance;
}

- (instancetype)initWithString:(NSString *)string {
    self = [super init];
    if (self) {
        _speechString = [string copy];
    }
    return self;
}

@end

@interface AVSpeechSynthesizer ()
@property(nonatomic, readwrite, getter=isSpeaking) BOOL speaking;
@end

@implementation AVSpeechSynthesizer

- (void)speakUtterance:(AVSpeechUtterance *)utterance {
    // No speech engine on iOS 6 via this API; accept the call as a no-op.
}

- (BOOL)stopSpeakingAtBoundary:(AVSpeechBoundary)boundary {
    self.speaking = NO;
    return YES;
}

- (BOOL)pauseSpeakingAtBoundary:(AVSpeechBoundary)boundary {
    return YES;
}

- (BOOL)continueSpeaking {
    return YES;
}

@end

struct __float2 __sincosf_stret(float __x) {
    struct __float2 __r;
    __r.__sinval = sinf(__x);
    __r.__cosval = cosf(__x);
    return __r;
}

struct __double2 __sincos_stret(double __x) {
    struct __double2 __r;
    __r.__sinval = sin(__x);
    __r.__cosval = cos(__x);
    return __r;
}

double __exp10(double __x) {
    return pow(10.0, __x);
}

float __exp10f(float __x) {
    return (float)pow(10.0, (double)__x);
}
