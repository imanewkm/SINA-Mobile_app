allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// Some Flutter plugins (e.g. tflite_flutter) pin a low compileSdk that is
// incompatible with their newer androidx transitive dependencies. Bump any
// android subproject compiling below 34 up to 36. Registered before the
// evaluationDependsOn block below so :app is not yet evaluated.
subprojects {
    val bumpCompileSdk: Project.() -> Unit = {
        val androidExt = extensions.findByName("android")
        if (androidExt is com.android.build.gradle.BaseExtension) {
            val level = androidExt.compileSdkVersion
                ?.substringAfter("android-")
                ?.toIntOrNull() ?: 0
            if (level in 1..33) {
                androidExt.compileSdkVersion(36)
            }
        }
    }
    if (state.executed) bumpCompileSdk() else afterEvaluate { bumpCompileSdk() }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
