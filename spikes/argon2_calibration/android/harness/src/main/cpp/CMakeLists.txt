# SPDX-License-Identifier: MPL-2.0
cmake_minimum_required(VERSION 3.22.1)
project(localhold_argon2_calibration LANGUAGES C)

find_package(sodium REQUIRED CONFIG)

add_library(localhold_argon2_calibration SHARED localhold_argon2_calibration.c)
target_compile_features(localhold_argon2_calibration PRIVATE c_std_11)
target_compile_options(
    localhold_argon2_calibration
    PRIVATE
    -Wall
    -Wextra
    -Werror
    -fstack-protector-strong
)
target_link_options(
    localhold_argon2_calibration
    PRIVATE
    -Wl,-z,relro
    -Wl,-z,now
    -Wl,-z,noexecstack
)
target_link_libraries(
    localhold_argon2_calibration
    PRIVATE
    sodium::sodium-minimal-static
)
