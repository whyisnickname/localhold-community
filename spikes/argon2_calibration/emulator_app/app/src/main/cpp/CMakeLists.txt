cmake_minimum_required(VERSION 3.22.1)
project(localhold_argon2_emulator LANGUAGES C)

if(ANDROID_ABI STREQUAL "arm64-v8a")
    set(LOCALHOLD_LIBSODIUM_ROOT "${LOCALHOLD_LIBSODIUM_ARM64_ROOT}")
elseif(ANDROID_ABI STREQUAL "x86_64")
    set(LOCALHOLD_LIBSODIUM_ROOT "${LOCALHOLD_LIBSODIUM_X86_ROOT}")
else()
    message(FATAL_ERROR "Unsupported diagnostic ABI: ${ANDROID_ABI}")
endif()

if(NOT EXISTS "${LOCALHOLD_LIBSODIUM_ROOT}/lib/libsodium.a")
    message(FATAL_ERROR "Verified libsodium archive is missing for ${ANDROID_ABI}")
endif()

add_library(sodium_minimal STATIC IMPORTED)
set_target_properties(
    sodium_minimal
    PROPERTIES IMPORTED_LOCATION "${LOCALHOLD_LIBSODIUM_ROOT}/lib/libsodium.a"
)

add_library(
    localhold_argon2_calibration
    SHARED
    "../../../../../android/harness/src/main/cpp/localhold_argon2_calibration.c"
)
target_include_directories(
    localhold_argon2_calibration
    PRIVATE "${LOCALHOLD_LIBSODIUM_ROOT}/include"
)
target_compile_options(
    localhold_argon2_calibration PRIVATE
    -Wall -Wextra -Werror -fstack-protector-strong
)
target_link_options(
    localhold_argon2_calibration PRIVATE
    -Wl,-z,relro -Wl,-z,now -Wl,-z,noexecstack
)
target_link_libraries(localhold_argon2_calibration PRIVATE sodium_minimal)
