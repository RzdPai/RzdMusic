# Copyright (c) 2026 RzdPai
#
# libmpvnative：把预编译的 libmpv.so 暴露成 ArkTS 可用的同步接口（见 ../mpv_bridge.cpp）。

cmake_minimum_required(VERSION 3.5.0)
project(libmpvnative)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

if(DEFINED PACKAGE_FIND_FILE)
    include(${PACKAGE_FIND_FILE})
endif()

include_directories(${NATIVERENDER_ROOT_PATH}
                    ${NATIVERENDER_ROOT_PATH}/include)

# 预编译的 libmpv.so 放在 src/main/libs/<abi>/（由 hvigor 打包进 HAP）
add_library(mpvnative SHARED mpv_bridge.cpp)

target_link_libraries(mpvnative PUBLIC
    libace_napi.z.so
    libhilog_ndk.z.so
    libc++_shared.so
)

# 链接预编译的 libmpv.so（CMakeLists 在 src/main/cpp，so 在 src/main/libs/<abi>）
target_link_libraries(mpvnative PUBLIC
    ${NATIVERENDER_ROOT_PATH}/../libs/${OHOS_ARCH}/libmpv.so
)
