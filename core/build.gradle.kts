import org.jetbrains.kotlin.gradle.plugin.mpp.apple.XCFramework

plugins {
    alias(libs.plugins.kotlin.multiplatform)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.ktlint)
    alias(libs.plugins.detekt)
}

// Tariffs are reviewed as JSON data in core/tariffs/ and embedded so both apps ship identical copies.
val bundleTariffs by tasks.registering {
    val sources = layout.projectDirectory.dir("tariffs")
    val output = layout.buildDirectory.dir("generated/tariffs")
    inputs.dir(sources)
    outputs.dir(output)
    doLast {
        val entries =
            sources.asFile.listFiles { file -> file.extension == "json" }!!.sortedBy { it.name }.joinToString("\n") {
                "        \"${it.nameWithoutExtension}\" to \"\"\"${it.readText().replace("$", "\${'$'}")}\"\"\","
            }
        val file = output.get().file("moneh/core/tariff/BundledTariffs.kt").asFile
        file.parentFile.mkdirs()
        file.writeText(
            "package moneh.core.tariff\n\n" +
                "/** Generated from core/tariffs/ by the bundleTariffs task. */\n" +
                "internal val bundledTariffJson: Map<String, String> =\n    mapOf(\n$entries\n    )\n",
        )
    }
}

kotlin {
    jvmToolchain(17)
    jvm()

    val xcf = XCFramework("MonehCore")
    listOf(iosArm64(), iosSimulatorArm64()).forEach {
        it.binaries.framework {
            baseName = "MonehCore"
            isStatic = true
            xcf.add(this)
        }
    }

    sourceSets {
        commonMain {
            kotlin.srcDir(bundleTariffs)
        }
        commonMain.dependencies {
            implementation(libs.kotlinx.datetime)
            implementation(libs.kotlincrypto.sha2)
            implementation(libs.kotlinx.serialization.json)
        }
        commonTest.dependencies {
            implementation(kotlin("test"))
        }
        jvmTest.dependencies {
            implementation(libs.kosherjava)
        }
    }
}

detekt {
    buildUponDefaultConfig = true
    config.setFrom(rootProject.file("config/detekt/detekt.yml"))
    source.setFrom("src/commonMain/kotlin", "src/commonTest/kotlin", "src/jvmTest/kotlin")
}

ktlint {
    filter { exclude { it.file.path.contains("generated") } }
}
