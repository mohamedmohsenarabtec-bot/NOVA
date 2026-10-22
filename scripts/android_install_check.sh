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
sleep 3
read -r retry_x retry_y < <(python3 - <<'PY'
import re, xml.etree.ElementTree as ET
nodes = ET.parse('.local/android-test/offline.xml').iter('node')
button = next(n for n in nodes if n.get('clickable') == 'true' and 'Retry' in n.get('content-desc', ''))
x1, y1, x2, y2 = map(int, re.findall(r'\d+', button.get('bounds')))
print((x1+x2)//2, (y1+y2)//2)
PY
)
adb shell input tap "$retry_x" "$retry_y"
sleep 20
adb exec-out screencap -p > "$evidence/recovered.png"
adb shell uiautomator dump /sdcard/nova-recovered.xml
adb pull /sdcard/nova-recovered.xml "$evidence/recovered.xml"
grep -q 'تسجيل الدخول' "$evidence/recovered.xml"
adb logcat -d -s AndroidRuntime:E flutter:E > "$evidence/runtime-final.txt"
if grep -q 'FATAL EXCEPTION\|Unhandled Exception' "$evidence/runtime-final.txt"; then exit 1; fi
echo 'PASS: published APK installed, reached Auth, exposed offline Retry and recovered through the real button.'
