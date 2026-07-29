// Minimal reimplementation of the MSVC CppUnitTest API so that the
// upstream engine test sources compile unmodified on macOS.
// Supports: TEST_CLASS, TEST_METHOD, TEST_METHOD_INITIALIZE,
// TEST_METHOD_CLEANUP, TEST_CLASS_INITIALIZE, Assert, Logger.

#pragma once

#include <cstdlib>
#include <cxxabi.h>
#include <functional>
#include <typeinfo>
#include <iostream>
#include <string>
#include <utility>
#include <vector>

namespace Microsoft::VisualStudio::CppUnitTestFramework
{
    struct TestFailure
    {
        std::wstring message;
    };

    class Assert
    {
    public:
        static void IsTrue(bool condition, const wchar_t* message = nullptr)
        {
            if (!condition)
            {
                Raise(message);
            }
        }

        static void IsFalse(bool condition, const wchar_t* message = nullptr)
        {
            if (condition)
            {
                Raise(message);
            }
        }

        [[noreturn]] static void Fail(const wchar_t* message = nullptr)
        {
            Raise(message);
        }

        template <typename T, typename U>
        static void AreEqual(const T& expected, const U& actual, const wchar_t* message = nullptr)
        {
            if (!(expected == actual))
            {
                Raise(message);
            }
        }

    private:
        [[noreturn]] static void Raise(const wchar_t* message)
        {
            throw TestFailure{ message != nullptr ? message : L"" };
        }
    };

    class Logger
    {
    public:
        static void WriteMessage(const wchar_t* message)
        {
            std::wcout << L"[log] " << (message != nullptr ? message : L"") << std::endl;
        }
        static void WriteMessage(const char* message)
        {
            std::cout << "[log] " << (message != nullptr ? message : "") << std::endl;
        }
    };

    struct TestRegistry
    {
        struct ClassEntry
        {
            std::string name;
            std::function<int()> runAll;
        };

        static std::vector<ClassEntry>& Classes()
        {
            static std::vector<ClassEntry> classes;
            return classes;
        }

        static int RunAllClasses()
        {
            int failures = 0;
            for (const auto& entry : Classes())
            {
                std::cout << "== " << entry.name << std::endl;
                failures += entry.runAll();
            }
            return failures;
        }
    };

    template <typename T>
    class TestClassBase
    {
    public:
        using ThisClass = T;
        using MethodFn = std::function<void(T&)>;

        struct Registry
        {
            std::vector<std::pair<std::string, MethodFn>> methods;
            MethodFn init;
            MethodFn cleanup;
            std::function<void()> classInit;
            bool classRegistered = false;
        };

        static Registry& GetRegistry()
        {
            static Registry registry;
            return registry;
        }

        static void EnsureClassRegistered()
        {
            auto& registry = GetRegistry();
            if (registry.classRegistered)
            {
                return;
            }
            registry.classRegistered = true;
            TestRegistry::Classes().push_back({ ClassName(), []() { return RunAllMethods(); } });
        }

        static std::string ClassName()
        {
            int status = 0;
            char* demangled = abi::__cxa_demangle(typeid(T).name(), nullptr, nullptr, &status);
            std::string name = (status == 0 && demangled != nullptr) ? demangled : typeid(T).name();
            std::free(demangled);
            return name;
        }

        static int RunAllMethods()
        {
            auto& registry = GetRegistry();
            if (registry.classInit)
            {
                registry.classInit();
            }

            int failures = 0;
            for (const auto& [name, method] : registry.methods)
            {
                T instance;
                bool passed = true;
                std::wstring failureMessage;
                try
                {
                    if (registry.init)
                    {
                        registry.init(instance);
                    }
                    method(instance);
                }
                catch (const TestFailure& failure)
                {
                    passed = false;
                    failureMessage = failure.message;
                }
                catch (const std::exception& ex)
                {
                    passed = false;
                    const char* what = ex.what();
                    failureMessage.assign(what, what + std::string(what).size());
                }
                catch (...)
                {
                    passed = false;
                    failureMessage = L"unknown exception";
                }

                if (registry.cleanup)
                {
                    try
                    {
                        registry.cleanup(instance);
                    }
                    catch (...)
                    {
                    }
                }

                if (passed)
                {
                    std::cout << "  PASS: " << name << std::endl;
                }
                else
                {
                    failures++;
                    std::cout << "  FAIL: " << name;
                    if (!failureMessage.empty())
                    {
                        std::wcout << L" -- " << failureMessage;
                    }
                    std::cout << std::endl;
                }
            }
            return failures;
        }

        static void AddMethod(const char* name, MethodFn method)
        {
            auto& methods = GetRegistry().methods;
            for (const auto& existing : methods)
            {
                if (existing.first == name)
                {
                    return;
                }
            }
            EnsureClassRegistered();
            methods.emplace_back(name, std::move(method));
        }

        struct MethodRegistrar
        {
            MethodRegistrar(const char* name, MethodFn method)
            {
                AddMethod(name, std::move(method));
            }
        };

        struct InitRegistrar
        {
            explicit InitRegistrar(MethodFn method)
            {
                GetRegistry().init = std::move(method);
            }
        };

        struct CleanupRegistrar
        {
            explicit CleanupRegistrar(MethodFn method)
            {
                GetRegistry().cleanup = std::move(method);
            }
        };

        struct ClassInitRegistrar
        {
            explicit ClassInitRegistrar(std::function<void()> func)
            {
                EnsureClassRegistered();
                GetRegistry().classInit = std::move(func);
            }
        };
    };
}

#define TEST_CLASS(className)                                                                                                                                  \
    class className : public ::Microsoft::VisualStudio::CppUnitTestFramework::TestClassBase<className>

#define TEST_METHOD(methodName)                                                                                                                                \
public:                                                                                                                                                        \
    MethodRegistrar s_methodReg_##methodName{ #methodName, [](ThisClass& self) { self.methodName(); } };                                                       \
    void methodName()

#define TEST_METHOD_INITIALIZE(methodName)                                                                                                                     \
public:                                                                                                                                                        \
    InitRegistrar s_initReg_##methodName{ [](ThisClass& self) { self.methodName(); } };                                                                        \
    void methodName()

#define TEST_METHOD_CLEANUP(methodName)                                                                                                                        \
public:                                                                                                                                                        \
    CleanupRegistrar s_cleanupReg_##methodName{ [](ThisClass& self) { self.methodName(); } };                                                                  \
    void methodName()

#define TEST_CLASS_INITIALIZE(methodName)                                                                                                                      \
public:                                                                                                                                                        \
    ClassInitRegistrar s_classInitReg_##methodName{ []() { ThisClass::methodName(); } };                                                                       \
    static void methodName()

// Construct one probe instance at namespace scope so the non-static
// registrar members run and populate the registry before main().
#define REGISTER_TEST_CLASS(qualifiedClassName)                                                                                                                \
    namespace                                                                                                                                                  \
    {                                                                                                                                                          \
        const bool s_probe_##__LINE__ = ((void)qualifiedClassName{}, true);                                                                                    \
    }
