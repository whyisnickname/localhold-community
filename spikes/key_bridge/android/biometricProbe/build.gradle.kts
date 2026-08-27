// SPDX-License-Identifier: MPL-2.0
plugins { id("com.android.application") }

val stageBiometricWrapper by tasks.registering(Copy::class) {
    from("../src/main/kotlin/dev/localhold/localhold_key_bridge/AndroidBiometricWrapper.kt")
    into(layout.buildDirectory.dir("generated/biometricProbe/kotlin"))
}

android {
    namespace = "dev.localhold.biometricprobe"
    compileSdk = 36

    defaultConfig {
        applicationId = "dev.localhold.biometricprobe"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "0.0.1"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    sourceSets.getByName("main").kotlin.srcDir(
        layout.buildDirectory.dir("generated/biometricProbe/kotlin").get().asFile,
    )

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

tasks.configureEach {
    if (name.startsWith("compile") && name.endsWith("Kotlin")) {
        dependsOn(stageBiometricWrapper)
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
}
