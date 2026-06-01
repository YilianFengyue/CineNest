pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        // 🌟 新增：Flutter 官方的国内镜像（放在最前面，优先去这里找）
        maven { url = java.net.URI("https://storage.flutter-io.cn/download.flutter.io") }

        // 阿里云 Gradle 插件镜像
        maven { url = java.net.URI("https://maven.aliyun.com/repository/public") }
        maven { url = java.net.URI("https://maven.aliyun.com/repository/google") }
        maven { url = java.net.URI("https://maven.aliyun.com/repository/gradle-plugin") }

        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

// 统一管理子项目依赖的仓库源
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        // 🌟 新增：Flutter 官方引擎依赖的国内镜像（必须放在最前面）
        maven { url = java.net.URI("https://storage.flutter-io.cn/download.flutter.io") }

        // 阿里云 Maven 中央仓库与 Google 镜像
        maven { url = java.net.URI("https://maven.aliyun.com/repository/public") }
        maven { url = java.net.URI("https://maven.aliyun.com/repository/google") }

        google()
        mavenCentral()
    }
}

include(":app")