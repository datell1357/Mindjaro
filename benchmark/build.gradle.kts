import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

plugins {
    alias(libs.plugins.android.test)
}

android {
    namespace = "com.maeumjaro.app.benchmark"
    compileSdk = 36

    // com.android.test modules compile their instrumentation sources from main.
    // Keep the benchmark sources in the existing androidTest directory while
    // making them part of the actual benchmark test APK.
    sourceSets["main"].java.srcDir("src/androidTest/java")

    defaultConfig {
        minSdk = 26
        targetSdk = 36
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    targetProjectPath = ":app"
}

tasks.withType<KotlinCompile>().configureEach {
    source("src/androidTest/java")
}

dependencies {
    implementation(libs.androidx.benchmark.macro.junit4)
    implementation(libs.androidx.test.uiautomator)
    implementation(libs.androidx.test.ext.junit)
    implementation(libs.androidx.test.runner)
}
