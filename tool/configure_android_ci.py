from pathlib import Path


JITPACK_URL = "https://jitpack.io"


def configure_project_repositories() -> None:
    build = Path("android/build.gradle")
    if not build.exists():
        build = Path("android/build.gradle.kts")
    if not build.exists():
        raise SystemExit("Android root build.gradle(.kts) not found")

    text = build.read_text()
    if JITPACK_URL in text:
        print(f"JitPack already configured in {build}")
        return

    if build.suffix == ".kts":
        jitpack = '        maven { url = uri("https://jitpack.io") }'
    else:
        jitpack = "        maven { url 'https://jitpack.io' }"

    marker = "allprojects"
    start = text.find(marker)
    if start >= 0:
        repo = text.find("mavenCentral()", start)
        if repo < 0:
            raise SystemExit(
                "allprojects block exists but mavenCentral() was not found"
            )
        insert_at = repo + len("mavenCentral()")
        text = text[:insert_at] + "\n" + jitpack + text[insert_at:]
    else:
        if build.suffix == ".kts":
            text += '''\n\nallprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") }
    }
}
'''
        else:
            text += '''\n\nallprojects {
    repositories {
        google()
        mavenCentral()
        maven { url 'https://jitpack.io' }
    }
}
'''

    build.write_text(text)

    if JITPACK_URL not in build.read_text():
        raise SystemExit("JitPack repository was not configured in root build file")
    print(f"Configured JitPack in {build}")


def configure_settings() -> None:
    settings = Path("android/settings.gradle.kts")
    kotlin = True
    if not settings.exists():
        settings = Path("android/settings.gradle")
        kotlin = False
    if not settings.exists():
        raise SystemExit("Android settings.gradle(.kts) not found")

    text = settings.read_text()
    if JITPACK_URL not in text:
        jitpack = (
            '        maven { url = uri("https://jitpack.io") }'
            if kotlin
            else "        maven { url 'https://jitpack.io' }"
        )
        marker = "dependencyResolutionManagement"
        start = text.find(marker)
        if start >= 0:
            repo = text.find("mavenCentral()", start)
            if repo < 0:
                raise SystemExit(
                    "dependencyResolutionManagement exists but mavenCentral() was not found"
                )
            insert_at = repo + len("mavenCentral()")
            text = text[:insert_at] + "\n" + jitpack + text[insert_at:]
        else:
            if kotlin:
                text += '''\n\ndependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") }
    }
}
'''
            else:
                text += '''\n\ndependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        maven { url 'https://jitpack.io' }
    }
}
'''
        settings.write_text(text)

    if JITPACK_URL not in settings.read_text():
        raise SystemExit("JitPack repository was not configured in settings")
    print(f"Configured JitPack in {settings}")


def configure_manifest() -> None:
    manifest = Path("android/app/src/main/AndroidManifest.xml")
    if not manifest.exists():
        raise SystemExit("AndroidManifest.xml not found")

    text = manifest.read_text()
    filters = '''        <intent-filter>
              <action android:name="android.intent.action.VIEW" />
              <category android:name="android.intent.category.DEFAULT" />
              <category android:name="android.intent.category.BROWSABLE" />
              <data android:scheme="negosmintwallet" android:host="connect" />
          </intent-filter>
          <intent-filter>
              <action android:name="android.intent.action.VIEW" />
              <category android:name="android.intent.category.DEFAULT" />
              <category android:name="android.intent.category.BROWSABLE" />
              <data android:scheme="wc" />
          </intent-filter>
'''

    if 'android:scheme="negosmintwallet"' not in text:
        marker = "        <intent-filter>"
        if marker not in text:
            raise SystemExit("Android manifest activity intent-filter marker not found")
        text = text.replace(marker, filters + marker, 1)
        manifest.write_text(text)
    elif 'android:scheme="wc"' not in text:
        raise SystemExit("negosmintwallet link exists but wc link is missing")

    print(f"Configured wallet deep links in {manifest}")


configure_project_repositories()
configure_settings()
configure_manifest()
