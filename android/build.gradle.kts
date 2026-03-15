allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Optional: set parkd.useTempBuildDir=true in local.properties to use temp dir (avoids file-lock issues; local only, gitignored)
val localProps = java.util.Properties()
val localFile = rootProject.file("local.properties")
val useTempBuild = localFile.exists() && run {
    localFile.inputStream().use { localProps.load(it) }
    localProps.getProperty("parkd.useTempBuildDir", "false") == "true"
}
if (useTempBuild) {
    val dirProp = rootProject.objects.directoryProperty()
    dirProp.set(java.io.File(System.getProperty("java.io.tmpdir"), "parkd_build"))
    rootProject.layout.buildDirectory.set(dirProp)
} else {
    val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
    rootProject.layout.buildDirectory.value(newBuildDir)
}

subprojects {
    val newSubprojectBuildDir = rootProject.layout.buildDirectory.dir(project.name)
    project.layout.buildDirectory.set(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
