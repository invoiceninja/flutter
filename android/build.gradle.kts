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
// AGP 9 checks each library's compileSdk against its dependencies' AAR
// metadata. super_keyboard (super_editor's, 0.4.2 included) still compiles
// against 34, and flutter_plugin_android_lifecycle requires 36 or later, so the
// build fails at :super_keyboard:checkDebugAarMetadata. Raise any plugin module
// below 36 to it. compileSdk only picks the API stubs a module compiles
// against; minSdk and targetSdk, which decide runtime behaviour, are untouched.
// Registered before evaluationDependsOn below, so it runs ahead of AGP's own
// afterEvaluate. docs/upstream-workarounds.md § 20.
subprojects {
    afterEvaluate {
        val android =
            extensions.findByName("android") as? com.android.build.gradle.LibraryExtension
                ?: return@afterEvaluate
        val current = android.compileSdkVersion?.removePrefix("android-")?.toIntOrNull()
        if (current != null && current < 36) android.compileSdkVersion(36)
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
