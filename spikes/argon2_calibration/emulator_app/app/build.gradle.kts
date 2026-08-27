// SPDX-License-Identifier: MPL-2.0
plugins { id("com.android.application") }

val libsodiumX86Root = providers.environmentVariable("LOCALHOLD_LIBSODIUM_X86_ROOT")
    .orElse(providers.gradleProperty("localholdLibsodiumX86Root"))
val libsodiumArm64Root = providers.environmentVariable("LOCALHOLD_LIBSODIUM_ARM64_ROOT")
    .orElse(providers.gradleProperty("localholdLibsodiumArm64Root"))

android {
    namespace = "dev.localhold.argon2.emulator"
    compileSdk = 36
    testBuildType = "release"
    defaultConfig {
        applicationId = "dev.localhold.argon2.emulator"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "0.0.1"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        ndk { abiFilters += listOf("x86_64", "arm64-v8a") }
        externalNativeBuild {
            cmake {
                arguments += listOf(
                    "-DLOCALHOLD_LIBSODIUM_X86_ROOT=${libsodiumX86Root.get()}",
                    "-DLOCALHOLD_LIBSODIUM_ARM64_ROOT=${libsodiumArm64Root.get()}",
                )
            }
        }
    }
    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }
    buildTypes {
        getByName("release") {
            // Release-optimized diagnostic code, signed only with the standard
            // disposable debug key so a physical diagnostic device can install it.
            // Never publish this artifact.
            signingConfig = signingConfigs.getByName("debug")
            isDebuggable = false
            isMinifyEnabled = false
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

kotlin {
    compilerOptions { jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17 }
}

dependencies {
    androidTestImplementation("androidx.test:runner:1.7.0")
    androidTestImplementation("androidx.test.ext:junit:1.3.0")
}
