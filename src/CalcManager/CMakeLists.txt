cmake_minimum_required(VERSION 3.20)
project(CalcManager CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

file(GLOB CALCMANAGER_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/*.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/CEngine/*.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/Ratpack/*.cpp
)
list(REMOVE_ITEM CALCMANAGER_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/pch.cpp)

add_library(CalcManager STATIC ${CALCMANAGER_SOURCES})

target_include_directories(CalcManager PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/Ratpack
)

option(CALCMANAGER_SMOKE_TEST "Build the CalcManager smoke test executable" OFF)
if(CALCMANAGER_SMOKE_TEST)
    add_executable(CalcManagerSmokeTest smoketest/main.cpp)
    target_link_libraries(CalcManagerSmokeTest PRIVATE CalcManager)
endif()
