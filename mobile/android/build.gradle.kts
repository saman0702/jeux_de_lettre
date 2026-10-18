allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Agora (et d'autres plugins) lisent ces ext ; sans ça ils restent en android-31.
extra["compileSdkVersion"] = 37
extra["targetSdkVersion"] = 36
extra["minSdkVersion"] = 24

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

// Force compileSdk récent pour les plugins Android (ex. agora_rtc_engine → 31).
// evaluationDependsOn(":app") peut déjà avoir évalué certains projets : gérer les deux cas.
subprojects {
    fun forceCompileSdk() {
        val android = extensions.findByName("android") ?: return
        try {
            val setCompileSdk =
                android.javaClass.methods.firstOrNull {
                    it.name == "setCompileSdkVersion" && it.parameterTypes.size == 1
                }
            setCompileSdk?.invoke(android, 37)
            val setCompileSdkInt =
                android.javaClass.methods.firstOrNull {
                    it.name == "setCompileSdk" &&
                        it.parameterTypes.size == 1 &&
                        it.parameterTypes[0] == Int::class.javaPrimitiveType
                }
            setCompileSdkInt?.invoke(android, 37)
        } catch (_: Exception) {
            // Plugins non-Android : ignorer.
        }
    }
    if (state.executed) {
        forceCompileSdk()
    } else {
        afterEvaluate { forceCompileSdk() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
