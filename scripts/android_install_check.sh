#!/usr/bin/env bash
set -euo pipefail
evidence=.local/android-test
adb install -r "$evidence/app-release.apk" | tee "$evidence/install.txt"
adb logcat -c
adb shell am start -W -n com.nova.app.nova/.MainActivity | tee "$evidence/launch.txt"
sleep 25
adb shell pidof com.nova.app.nova | tee "$evidence/pid.txt"
adb exec-out screencap -p > "$evidence/online.png"
adb shell uiautomator dump /sdcard/nova-online.xml
adb pull /sdcard/nova-online.xml "$evidence/online.xml"
adb logcat -d -s AndroidRuntime:E flutter:E > "$evidence/runtime.txt"
adb logcat -d -s flutter:I > "$evidence/flutter-startup.txt"
adb shell date -u > "$evidence/device-time.txt"
adb shell settings get global http_proxy > "$evidence/proxy.txt"
if grep -q 'FATAL EXCEPTION' "$evidence/runtime.txt"; then exit 1; fi
if grep -q 'Retry' "$evidence/online.xml"; then
  echo 'INCOMPLETE: installed APK did not reach authentication while online.'
  exit 1
fi
# Require the actual Arabic default authentication screen, not just a live PID.
grep -q 'تسجيل الدخول' "$evidence/online.xml"
# A disconnected startup must draw a Flutter error/retry view, never hang on
# the OS launch image. No accounts or passwords are used in this test.
adb shell am force-stop com.nova.app.nova
adb shell svc wifi disable
adb shell svc data disable
adb shell am start -W -n com.nova.app.nova/.MainActivity
sleep 30
adb exec-out screencap -p > "$evidence/offline.png"
adb shell uiautomator dump /sdcard/nova-offline.xml
adb pull /sdcard/nova-offline.xml "$evidence/offline.xml"
grep -q 'Retry' "$evidence/offline.xml"
adb shell svc wifi enable
adb shell svc data enable
echo 'PASS: published APK installed, launched, stayed alive, and exposed offline Retry.'
