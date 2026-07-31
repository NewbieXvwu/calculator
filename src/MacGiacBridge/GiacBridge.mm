#import "GiacBridge.h"

#include <fcntl.h>
#include <unistd.h>
#include <iostream>

// libgiac.a 导出的最小 C 求值入口（src/giac/caseval.cc）。
extern "C" const char *caseval(const char *);

@implementation GiacEngine

+ (NSString *)evaluate:(NSString *)expression {
    return [self evaluate:expression warningsOut:NULL];
}

+ (NSString *)evaluate:(NSString *)expression warningsOut:(NSString *__autoreleasing *)warningsOut {
    static NSLock *lock;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ lock = [[NSLock alloc] init]; });

    [lock lock];

    // giac 的警告经 std::cerr（fd 2）输出。捕获方式：临时把 fd 2 指到管道，
    // 求值后恢复并读回。写端非阻塞，防止极端多警告时管道写满死锁（超出
    // 缓冲的警告被丢弃，宁可漏采警告文本也不能挂起求值线程）。
    int savedErr = -1;
    int fds[2] = { -1, -1 };
    if (warningsOut && pipe(fds) == 0) {
        fcntl(fds[1], F_SETFL, O_NONBLOCK);
        savedErr = dup(STDERR_FILENO);
        if (savedErr >= 0) {
            dup2(fds[1], STDERR_FILENO);
        } else {
            close(fds[0]);
            close(fds[1]);
            fds[0] = fds[1] = -1;
        }
    }

    const char *result = caseval(expression.UTF8String);
    NSString *text = result ? [NSString stringWithUTF8String:result] : nil;

    if (savedErr >= 0) {
        fflush(stderr);
        dup2(savedErr, STDERR_FILENO);
        close(savedErr);
        close(fds[1]);
        // 非阻塞写满会置 cerr 的 badbit，恢复后必须清掉，否则后续警告全丢。
        std::cerr.clear();

        NSMutableData *captured = [NSMutableData data];
        fcntl(fds[0], F_SETFL, O_NONBLOCK);
        char buf[4096];
        ssize_t n;
        while ((n = read(fds[0], buf, sizeof(buf))) > 0) {
            [captured appendBytes:buf length:(NSUInteger)n];
        }
        close(fds[0]);
        *warningsOut = [[NSString alloc] initWithData:captured encoding:NSUTF8StringEncoding] ?: @"";
    } else if (warningsOut) {
        *warningsOut = @"";
    }

    [lock unlock];

    return text ?: @"GIAC_ERROR: null result";
}

@end
