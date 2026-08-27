// SPDX-License-Identifier: MPL-2.0
plugins { id("com.android.application") }

android {
    namespace = "dev.localhold.backup.spike"
    compileSdk = 36
    defaultConfig {
        applicationId = "dev.localhold.backup.spike"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "0.0.1"
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("androidx.work:work-runtime:2.11.2")
    testImplementation("junit:junit:4.13.2")
}
