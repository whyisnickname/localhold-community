# SPDX-License-Identifier: MPL-2.0
cmake_minimum_required(VERSION 3.22.1)
project(localhold_vault_crypto C)

add_library(localhold_vault_crypto SHARED localhold_vault_crypto.c)

add_library(sodium SHARED IMPORTED)
set_target_properties(
  sodium
  PROPERTIES IMPORTED_LOCATION
  "${CMAKE_CURRENT_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}/libsodium.so"
)

target_include_directories(
  localhold_vault_crypto
  PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/include"
)

target_link_libraries(localhold_vault_crypto sodium)
