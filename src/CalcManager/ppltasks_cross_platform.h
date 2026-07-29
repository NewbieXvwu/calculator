#pragma once

#if defined(_WIN32) && defined(_MSC_VER)

#include <ppltasks.h>

#else

#include <utility>

// Minimal synchronous stand-in for PPL tasks, sufficient for CalcManager's usage
// (task_from_result + a single .then continuation in UnitConverter).
namespace concurrency
{
    template <typename T>
    class task
    {
    public:
        task() = default;
        explicit task(T value)
            : m_value(std::move(value))
        {
        }

        template <typename F>
        auto then(F&& func) const -> task<decltype(func(std::declval<T>()))>
        {
            using U = decltype(func(std::declval<T>()));
            return task<U>(func(m_value));
        }

        T get() const
        {
            return m_value;
        }

    private:
        T m_value{};
    };

    template <typename T>
    task<T> task_from_result(T value)
    {
        return task<T>(std::move(value));
    }
}

#endif
