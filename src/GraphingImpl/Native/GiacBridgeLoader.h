// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#pragma once

#include <string>
#include <cstring>

// libgiac_bridge.dll（P-Windows 求值器 A 方案，见 src/GraphingImpl/GiacBridge）的
// 延迟加载包装：LoadLibrary + GetProcAddress。MinGW ABI 与 MSVC 不兼容，
// DLL 的纯 C ABI（giac_bridge.h）是唯一通道。
//
// DLL 查找顺序：进程目录 → 系统目录 → PATH。打包进 AppX 时作为 Content 与
// GraphingImpl.dll 同目录即可被 LoadLibrary 找到。
namespace NativeGraphingImpl
{
    // 单例访问；首次调用时加载 DLL。失败返回 false，GetLastErrorString 给出原因。
    // 幂等：失败后不会重复尝试，除非 ResetForTest。
    class GiacBridgeLoader
    {
    public:
        static GiacBridgeLoader& Instance();

        // 求值一条 giac 表达式；返回 false 表示加载失败或引擎内部异常
        //（out 中为 "GIAC_ERROR:" 开头的文本）。warnings 可选。
        bool Evaluate(
            const char* expr,
            std::string& out,
            std::string* warnings = nullptr);

        // 测试用：强制下次重新加载（模拟 DLL 就位）。
        static void ResetForTest();

        bool IsLoaded() const { return m_loaded; }
        const std::wstring& LastError() const { return m_lastError; }

    private:
        GiacBridgeLoader();
        bool Load();
        void Unload();

        using GiacEvaluateFn = int (*)(const char*, char*, unsigned int, char*, unsigned int);

        bool m_loaded = false;
        std::wstring m_lastError;
        void* m_module = nullptr;
        GiacEvaluateFn m_evaluate = nullptr;
    };
}
