#include <clocale>
#include <iostream>

#include <CppUnitTest.h>

int main()
{
    std::setlocale(LC_ALL, "en_US.UTF-8");

    using Microsoft::VisualStudio::CppUnitTestFramework::TestRegistry;
    const int failures = TestRegistry::RunAllClasses();

    std::cout << (failures == 0 ? "ALL TESTS PASSED" : "FAILURES: ") << (failures == 0 ? "" : std::to_string(failures)) << std::endl;
    return failures == 0 ? 0 : 1;
}
