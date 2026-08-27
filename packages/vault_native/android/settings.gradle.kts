// SPDX-License-Identifier: MPL-2.0

pluginManagement {
    plugins {
        id("com.android.library") version "9.1.0"
        id("com.android.application") version "9.1.0"
    }
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

rootProject.name = "localhold_key_bridge"
include(":biometricProbe")
