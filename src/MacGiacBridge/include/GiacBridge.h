// Giac CAS 桥接：以 ObjC 接口包一层 giac 的 caseval C API，供 Swift 调用。
// 线程安全：caseval 使用全局 context，内部用串行锁保护。
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GiacEngine : NSObject

/// 求值一条 Giac/Xcas 表达式，返回结果字符串；解析失败时返回以
/// "GIAC_ERROR:" 开头的字符串（caseval 本身不抛异常）。
+ (NSString *)evaluate:(NSString *)expression;

/// 同上，并捕获求值期间 giac 写往 stderr 的警告文本（如
/// "Auto assume"、"Solving by bisection"）。诚实性加固（TODO S3·R3/R4）
/// 依赖这些警告判定结果是否可信。warningsOut 传 NULL 时不捕获。
+ (NSString *)evaluate:(NSString *)expression warningsOut:(NSString *_Nullable __autoreleasing *_Nullable)warningsOut;

@end

NS_ASSUME_NONNULL_END
