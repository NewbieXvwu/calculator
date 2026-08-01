#import "GiacBridge.h"

#include <fcntl.h>
#include <unistd.h>
#include <iostream>

// libgiac.a 导出的最小 C 求值入口（src/giac/caseval.cc）。
extern "C" const char *caseval(const char *);

// B-5 警告排空：求值期间持续读管道（pthread 同步创建，保证在写端关闭前
// 进入阻塞读——dispatch_async 的调度延迟会错过毫秒级短查询的全部数据）。
struct GiacDrainCtx {
    int fd;
    __unsafe_unretained NSMutableData *data;
};
static void *giac_drain_read(void *arg) {
    GiacDrainCtx *c = (GiacDrainCtx *)arg;
    char buf[4096];
    ssize_t n;
    while ((n = read(c->fd, buf, sizeof(buf))) > 0) {
        @synchronized(c->data) { [c->data appendBytes:buf length:(NSUInteger)n]; }
    }
    return NULL;
}

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

    const char *result = NULL;
    NSString *text = nil;
    NSString *capturedWarnings = @"";
    // 求值期间持续排空管道的读线程（攻击审查 B-5）：非阻塞写端写满后
    // 尾部（最新、最相关的）警告会丢失——诚实性判定依赖尾部警告文本
    // （"switching to approx"/"bisection"）。读端 drain 保住尾部。
    NSMutableData *captured = [NSMutableData data];
    pthread_t drainThread = 0;
    GiacDrainCtx drainCtx;
    if (fds[0] >= 0) {
        drainCtx.fd = fds[0];
        drainCtx.data = captured;
        if (pthread_create(&drainThread, NULL, giac_drain_read, &drainCtx) != 0) {
            drainThread = 0;
        }
    }
    @try {
        // 串行锁内求值。注意：caseval 内部可能抛出非 runtime_error 异常
        // （如 std::bad_alloc），且 caseval 自身无 try/catch——必须用
        // @finally 保证锁释放与 fd 2 恢复，否则一次异常泄漏后：
        //  1) NSLock 永不解锁 → 全部后续 evaluate 永久死锁；
        //  2) fd 2 永久指向已关闭的管道 → 全进程 stderr 静默丢失。
        result = caseval(expression.UTF8String);
        text = result ? [NSString stringWithUTF8String:result] : nil;

        if (savedErr >= 0) {
            fflush(stderr);
            dup2(savedErr, STDERR_FILENO);
            close(savedErr);
            savedErr = -1;
            // 关闭写端 → drain 线程读到 EOF → join（正常路径）。
            close(fds[1]);
            fds[1] = -1;
            // 非阻塞写满会置 cerr 的 badbit，恢复后必须清掉，否则后续警告全丢。
            std::cerr.clear();
            // 管道写满还可能置 stdio FILE 层的 error 指示器（fflush 失败），
            // 一并清掉，否则 printf/fputs 路径的 stderr 持续静默失败。
            clearerr(stderr);
        }
    } @finally {
        // 异常路径兜底：恢复 fd 2 并释放全部描述符（与正常路径同构）。
        if (savedErr >= 0) {
            dup2(savedErr, STDERR_FILENO);
            close(savedErr);
            std::cerr.clear();
            clearerr(stderr);
        }
        // 关闭写端并等待 drain 线程结束（异常时 fds[1] 可能仍开着）。
        if (fds[1] >= 0) { close(fds[1]); fds[1] = -1; }
        if (drainThread) { pthread_join(drainThread, NULL); drainThread = 0; }
        if (fds[0] >= 0) { close(fds[0]); fds[0] = -1; }

        if (warningsOut) {
            NSData *raw;
            @synchronized(captured) { raw = [captured copy]; }
            // B-2 内容过滤：fd 2 劫持是进程级的，捕获窗口内其他线程的
            // stderr（NSLog/printf 诊断）会混入——只保留 giac 警告特征行，
            // 防伪造 CAS 警告进入诚实性判定。
            NSString *all = [[NSString alloc] initWithData:raw encoding:NSUTF8StringEncoding] ?: @"";
            NSMutableArray<NSString *> *kept = [NSMutableArray array];
            for (NSString *line in [all componentsSeparatedByString:@"\n"]) {
                NSString *low = line.lowercaseString;
                if ([low containsString:@"periodic"] || [low containsString:@"assume"]
                    || [low containsString:@"approx"] || [low containsString:@"bisection"]
                    || [low containsString:@"warning"] || [low containsString:@"error"]) {
                    [kept addObject:line];
                }
            }
            // B-5 尾部保留：洪泛时只保留最后 256KB（最新警告对诚实性判定最相关）。
            NSString *filtered = [kept componentsJoinedByString:@"\n"];
            if (filtered.length > 256 * 1024) {
                filtered = [filtered substringFromIndex:filtered.length - 256 * 1024];
            }
            capturedWarnings = filtered;
        }
        if (warningsOut) {
            *warningsOut = capturedWarnings;
        }
        [lock unlock];
    }

    return text ?: @"GIAC_ERROR: null result";
}

@end
