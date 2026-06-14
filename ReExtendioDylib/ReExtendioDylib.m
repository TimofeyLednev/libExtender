#import <Foundation/Foundation.h>

struct __float2 { float __sinval; float __cosval; };
struct __double2 { double __sinval; double __cosval; };

static NSString *REStringFromObject(id value) {
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

static NSString *REPercentDecode(NSString *value) {
    return value ? [value stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] : nil;
}

static NSString *REPercentEncode(NSString *value) {
    return value ? [value stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] : nil;
}

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
