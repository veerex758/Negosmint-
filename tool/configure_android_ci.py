from pathlib import Path


def configure_settings() -> None:
    settings = Path("android/settings.gradle.kts")
    kotlin = True
    if not settings.exists():
        settings = Path("android/settings.gradle")
        kotlin = False
    if not settings.exists():
        raise SystemExit("Android settings.gradle(.kts) not found")

    text = settings.read_text()
    if "https://jitpack.io" not in text:
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

    if "https://jitpack.io" not in settings.read_text():
        raise SystemExit("JitPack repository was not configured")
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


configure_settings()
configure_manifest()
