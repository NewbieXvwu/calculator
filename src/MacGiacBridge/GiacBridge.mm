#import "GiacBridge.h"

// libgiac.a 导出的最小 C 求值入口（src/giac/caseval.cc）。
extern "C" const char *caseval(const char *);

@implementation GiacEngine

+ (NSString *)evaluate:(NSString *)expression {
    static NSLock *lock;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ lock = [[NSLock alloc] init]; });

    [lock lock];
    const char *result = caseval(expression.UTF8String);
    NSString *text = result ? [NSString stringWithUTF8String:result] : nil;
    [lock unlock];

    return text ?: @"GIAC_ERROR: null result";
}

@end
