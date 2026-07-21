plugins {
    id("com.android.application")
    id("com.chaquo.python")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.himark.editor"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Permanent -- F-Droid keys its listing on this; it must never change.
        applicationId = "dev.himark.editor"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Chaquopy ships one interpreter per ABI, so the list is a size
        // decision as much as a coverage one. These three are what
        // `jniLibs/` already carries for the Rust engine; the two must agree,
        // or an ABI gets a compiler with no engine (or the reverse).
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64")
        }
    }

    buildTypes {
        release {
            // F-Droid builds from source and signs with its own key, so no
            // signing config ships here. Debug keys keep `flutter run
            // --release` working locally.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

// The embedded compiler. Its own extension rather than a block inside
// `defaultConfig`: that spelling is Chaquopy's Groovy DSL, and this build is
// Kotlin DSL, where the plugin exposes one typed extension instead.
chaquopy {
    defaultConfig {
        // Pinned to the repository's own `.python-version`, so the device runs
        // the compiler on the interpreter it is tested against.
        version = "3.11"
        pip {
            // The whole on-device dependency list. It is one entry, and that is
            // the reason this is tractable at all: `antlr4-python3-runtime` is
            // pure Python, so there is no native wheel to cross-compile for
            // three ABIs. Held at the same pin as `pyproject.toml` -- the
            // generated parser under `hejmark/adapters/_gen` is version-matched
            // to its runtime.
            install("antlr4-python3-runtime==4.13.2")
        }
    }
    // `src/main/python` is the default, and holds two things: the entry point
    // `himark_compiler.py`, which is committed, and the `hejmark` package,
    // which is staged there by `tool/stage_python.sh` and gitignored -- the
    // same generated-not-vendored rule the engine's `.so` files follow.
}

// An APK with no staged compiler is the same easy mistake as one with no
// engine: the build succeeds, and the app says "engine unavailable" on a device.
// The engine's absence at least fails at load; a missing Python package would
// fail on the first keystroke, in a text field. So it fails here instead.
val checkStagedCompiler =
    tasks.register("checkStagedCompiler") {
        doFirst {
            if (!file("src/main/python/hejmark/__init__.py").exists()) {
                throw GradleException(
                    "the Python compiler is not staged: run gui/tool/stage_python.sh " +
                        "(and gui/tool/build_engine.sh for the engine beside it)",
                )
            }
        }
    }

tasks.matching { it.name == "preBuild" }.configureEach {
    dependsOn(checkStagedCompiler)
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
