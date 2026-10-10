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

    if 'android:host="ownership"' not in text:
        ownership_filter = """        <intent-filter>
              <action android:name="android.intent.action.VIEW" />
              <category android:name="android.intent.category.DEFAULT" />
              <category android:name="android.intent.category.BROWSABLE" />
              <data android:scheme="negosmintwallet" android:host="ownership" />
          </intent-filter>
"""
        marker = "        <intent-filter>"
        if marker not in text:
            raise SystemExit("Android manifest activity intent-filter marker not found")
        text = text.replace(marker, ownership_filter + marker, 1)
        manifest.write_text(text)

    print(f"Configured wallet deep links in {manifest}")



def configure_native_ownership_result() -> None:
    import re

    candidates = list(Path("android/app/src/main/kotlin").rglob("MainActivity.kt"))
    if len(candidates) != 1:
        raise SystemExit(
            f"Expected one generated MainActivity.kt, found {len(candidates)}"
        )
    activity = candidates[0]
    current = activity.read_text()
    match = re.search(r"^package ([A-Za-z0-9_.]+)", current, re.MULTILINE)
    if match is None:
        raise SystemExit("Could not determine generated Android package name")
    package_name = match.group(1)
    native_source = """package __PACKAGE__

import android.app.Activity
import android.content.Intent
import org.json.JSONObject
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.negosmint.wallet/ownership_result"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "completeOwnershipHandoff" -> {
                    val args = call.arguments as? Map<*, *>
                    val challengeId = args?.get("challengeId") as? String
                    val address = args?.get("walletAddress") as? String
                    val chainId = args?.get("chainId") as? Number
                    val signature = args?.get("signature") as? String
                    if (challengeId.isNullOrBlank() || challengeId.length > 64 ||
                        address == null || !Regex("^0x[0-9a-fA-F]{40}$").matches(address) ||
                        chainId?.toInt() != 11155111 ||
                        signature == null || !Regex("^0x[0-9a-fA-F]{130}$").matches(signature)) {
                        result.error("INVALID_OWNERSHIP_RESULT", "Invalid wallet ownership result.", null)
                        return@setMethodCallHandler
                    }
                    val payload = JSONObject()
                        .put("challengeId", challengeId)
                        .put("walletAddress", address)
                        .put("chainId", 11155111)
                        .put("signature", signature)
                        .toString()
                    setResult(
                        Activity.RESULT_OK,
                        Intent().putExtra("negosmint_wallet_ownership_result", payload)
                    )
                    result.success(true)
                    finish()
                }
                "rejectOwnershipHandoff" -> {
                    setResult(Activity.RESULT_CANCELED)
                    result.success(true)
                    finish()
                }
                else -> result.notImplemented()
            }
        }
    }
}
""".replace("__PACKAGE__", package_name)
    if current != native_source:
        activity.write_text(native_source)
    print(f"Configured native wallet ownership result bridge in {activity}")


configure_project_repositories()
configure_settings()
configure_manifest()
configure_native_ownership_result()
