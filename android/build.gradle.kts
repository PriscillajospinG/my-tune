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
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    val configureNamespace: () -> Unit = {
        val android = extensions.findByName("android")
        if (android != null) {
            try {
                val namespaceField = android.javaClass.getMethod("getNamespace")
                val currentNamespace = namespaceField.invoke(android) as? String
                if (currentNamespace.isNullOrEmpty()) {
                    val setter = android.javaClass.getMethod("setNamespace", String::class.java)
                    val ns = when {
                        name.contains("on_audio_query") -> "com.lucasjosino.on_audio_query"
                        group.toString().isNotEmpty() -> group.toString()
                        else -> "com.example.${name.replace('-', '_')}"
                    }
                    setter.invoke(android, ns)
                }
            } catch (_: Exception) {
            }
        }
    }

    if (state.executed) {
        configureNamespace()
    } else {
        afterEvaluate {
            configureNamespace()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

