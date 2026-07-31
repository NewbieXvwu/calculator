// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#include "pch.h"
#include "GiacBridgeLoader.h"

#include <windows.h>
#include <cstring>

namespace NativeGraphingImpl
{
    namespace
    {
        // 与 src/GraphingImpl/GiacBridge/giac_bridge.h 的 C ABI 约定严格一致。
        constexpr wchar_t kBridgeDllName[] = L"libgiac_bridge.dll";
        constexpr char kEvaluateSymbol[] = "giac_bridge_evaluate";
        constexpr char kInitSymbol[] = "giac_bridge_init";
        using GiacInitFn = void (*)();
    }

    GiacBridgeLoader& GiacBridgeLoader::Instance()
    {
        static GiacBridgeLoader loader;
        return loader;
    }

    GiacBridgeLoader::GiacBridgeLoader()
    {
        Load();
    }

    void GiacBridgeLoader::ResetForTest()
    {
        Instance().Unload();
        Instance().Load();
    }

    bool GiacBridgeLoader::Load()
    {
        if (m_loaded)
        {
            return true;
        }
        m_module = reinterpret_cast<void*>(LoadLibraryW(kBridgeDllName));
        if (!m_module)
        {
            m_lastError = std::wstring(L"LoadLibrary(") + kBridgeDllName + L") failed: error " + std::to_wstring(GetLastError());
            return false;
        }
        const auto init = reinterpret_cast<GiacInitFn>(GetProcAddress(reinterpret_cast<HMODULE>(m_module), kInitSymbol));
        if (init)
        {
            init();
        }
        m_evaluate = reinterpret_cast<GiacEvaluateFn>(GetProcAddress(reinterpret_cast<HMODULE>(m_module), kEvaluateSymbol));
        if (!m_evaluate)
        {
            m_lastError = std::wstring(L"GetProcAddress(") + L"giac_bridge_evaluate" + L") failed";
            Unload();
            return false;
        }
        m_loaded = true;
        return true;
    }

    void GiacBridgeLoader::Unload()
    {
        if (m_module)
        {
            FreeLibrary(reinterpret_cast<HMODULE>(m_module));
            m_module = nullptr;
        }
        m_evaluate = nullptr;
        m_loaded = false;
    }

    bool GiacBridgeLoader::Evaluate(const char* expr, std::string& out, std::string* warnings)
    {
        if (!m_loaded && !Load())
        {
            out = "GIAC_ERROR: bridge dll not loaded";
            return false;
        }
        std::string result(1 << 16, '\0');
        std::string warn(1 << 16, '\0');
        const int rc = m_evaluate(
            expr,
            result.data(), static_cast<unsigned int>(result.size()),
            warnings ? warn.data() : nullptr, warnings ? static_cast<unsigned int>(warn.size()) : 0);
        result.resize(std::strlen(result.data()));
        warn.resize(std::strlen(warn.data()));
        out = std::move(result);
        if (warnings)
        {
            *warnings = std::move(warn);
        }
        return rc == 0;
    }
}
