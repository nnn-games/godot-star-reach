"""Build debug APK, install to connected Android device, launch, stream Godot logs.

사용 예:
    python tools/android_test.py                # 빌드 → 설치 → 실행 → 로그
    python tools/android_test.py --no-build     # 기존 APK 재설치만
    python tools/android_test.py --no-logs      # 실행까지만
    python tools/android_test.py --scene res://main.tscn
    python tools/android_test.py --no-install --no-launch --no-logs  # 빌드만

환경변수:
    GODOT_BIN    Godot 실행파일 경로 (기본: C:\\Godot\\Godot_v4.6.2-stable_win64.exe)
    ANDROID_HOME Android SDK 루트 (adb 탐색에 사용)

사전조건:
    - Godot 에디터 Editor Settings → Export → Android 에서
      Java Sdk Path / Debug Keystore 설정이 완료되어 있어야 함
    - USB 디버깅 켠 디바이스가 adb 로 인식되거나, 에뮬레이터가 기동 중
"""
from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

PROJECT_DIR: Path = Path(__file__).resolve().parents[1]
BUILD_DIR: Path = PROJECT_DIR / "build" / "android"
APK_PATH: Path = BUILD_DIR / "tetris-debug.apk"
PROJECT_FILE: Path = PROJECT_DIR / "project.godot"
EXPORT_PRESETS: Path = PROJECT_DIR / "export_presets.cfg"
DEFAULT_SCENE: str = "res://scenes/tetris/tetris.tscn"
PRESET_NAME: str = "Android"
PACKAGE_NAME: str = "com.nnngames.starreach"

GODOT_BIN: str = os.environ.get(
    "GODOT_BIN",
    r"C:\Godot\Godot_v4.6.2-stable_win64.exe",
)

MAIN_SCENE_RE = re.compile(r'run/main_scene="([^"]+)"')


def _resolve_adb() -> str:
    found: str | None = shutil.which("adb")
    if found:
        return found
    android_home: str | None = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT")
    if android_home:
        candidate: Path = Path(android_home) / "platform-tools" / "adb.exe"
        if candidate.exists():
            return str(candidate)
    fallback: Path = Path.home() / "AppData" / "Local" / "Android" / "Sdk" / "platform-tools" / "adb.exe"
    if fallback.exists():
        return str(fallback)
    sys.exit("[err] adb 를 찾을 수 없습니다. ANDROID_HOME 환경변수 설정 또는 platform-tools 를 PATH 에 추가하세요.")


def _check_preconditions() -> None:
    if not Path(GODOT_BIN).exists():
        sys.exit(f"[err] Godot 실행파일 없음: {GODOT_BIN}\n      GODOT_BIN 환경변수로 경로 지정 가능.")
    if not EXPORT_PRESETS.exists():
        sys.exit(f"[err] {EXPORT_PRESETS} 없음.")
    presets: str = EXPORT_PRESETS.read_text(encoding="utf-8")
    if f'name="{PRESET_NAME}"' not in presets:
        sys.exit(f"[err] '{PRESET_NAME}' 프리셋이 export_presets.cfg 에 없음.")


def _swap_main_scene(target: str) -> str:
    text: str = PROJECT_FILE.read_text(encoding="utf-8")
    match = MAIN_SCENE_RE.search(text)
    if not match:
        sys.exit("[err] project.godot 에 run/main_scene 없음.")
    original: str = match.group(1)
    if original != target:
        PROJECT_FILE.write_text(
            MAIN_SCENE_RE.sub(f'run/main_scene="{target}"', text, count=1),
            encoding="utf-8",
        )
    return original


def build(scene: str) -> None:
    _check_preconditions()
    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    print(f"[build] main_scene → {scene}")
    original: str = _swap_main_scene(scene)
    try:
        cmd: list[str] = [
            GODOT_BIN,
            "--path", str(PROJECT_DIR),
            "--headless",
            "--export-debug", PRESET_NAME,
            str(APK_PATH),
        ]
        print(f"[build] {' '.join(cmd)}")
        result = subprocess.run(cmd)
        if result.returncode != 0:
            sys.exit(f"[err] Godot 내보내기 실패 (exit {result.returncode}). "
                     "Editor Settings 의 Java SDK / Debug Keystore 설정 확인.")
        if not APK_PATH.exists():
            sys.exit(f"[err] APK 가 생성되지 않음: {APK_PATH}")
        size_kb: int = APK_PATH.stat().st_size // 1024
        print(f"[build] OK → {APK_PATH} ({size_kb} KB)")
    finally:
        _swap_main_scene(original)
        print(f"[build] main_scene 복구 → {original}")


def _list_devices(adb: str) -> tuple[list[str], list[str]]:
    """Return (ready_devices, unauthorized_devices)."""
    result = subprocess.run([adb, "devices"], capture_output=True, text=True, check=True)
    ready: list[str] = []
    unauth: list[str] = []
    for line in result.stdout.splitlines()[1:]:
        parts: list[str] = line.strip().split()
        if len(parts) < 2:
            continue
        serial, state = parts[0], parts[1]
        if state == "device":
            ready.append(serial)
        elif state == "unauthorized":
            unauth.append(serial)
    return ready, unauth


def install(adb: str) -> str:
    if not APK_PATH.exists():
        sys.exit(f"[err] {APK_PATH} 없음. --no-build 빼고 먼저 빌드하세요.")
    ready, unauth = _list_devices(adb)
    if unauth:
        print(f"[install] 경고: 미인증 디바이스 {unauth}. 폰 화면에서 'USB 디버깅 허용' 대화상자 확인.",
              file=sys.stderr)
    if not ready:
        sys.exit("[err] 준비된 Android 디바이스가 없습니다 (adb devices 로 확인).")
    target: str = ready[0]
    if len(ready) > 1:
        print(f"[install] 연결 {len(ready)}대. 첫 번째({target}) 에 설치.")
    else:
        print(f"[install] 디바이스: {target}")
    result = subprocess.run([adb, "-s", target, "install", "-r", str(APK_PATH)])
    if result.returncode != 0:
        sys.exit(f"[err] adb install 실패 (exit {result.returncode})")
    print("[install] OK")
    return target


def launch(adb: str, serial: str | None) -> None:
    cmd: list[str] = [adb]
    if serial:
        cmd += ["-s", serial]
    cmd += ["shell", "monkey", "-p", PACKAGE_NAME,
            "-c", "android.intent.category.LAUNCHER", "1"]
    print(f"[launch] {PACKAGE_NAME}")
    result = subprocess.run(cmd, capture_output=True, text=True)
    output: str = (result.stdout or "") + (result.stderr or "")
    if "Events injected: 1" in output:
        print("[launch] OK")
    else:
        print(f"[launch] 응답 확인 필요:\n{output}", file=sys.stderr)


def stream_logs(adb: str, serial: str | None) -> None:
    base: list[str] = [adb]
    if serial:
        base += ["-s", serial]
    subprocess.run(base + ["logcat", "-c"], check=False)
    print("[logs] godot 관련 태그만 표시. Ctrl+C 로 종료.")
    try:
        subprocess.run(base + [
            "logcat", "-v", "tag",
            "godot:V", "GodotEngine:V", "Godot:V", "AndroidRuntime:E", "*:S",
        ])
    except KeyboardInterrupt:
        print("\n[logs] stopped.")


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    ap.add_argument("--scene", default=DEFAULT_SCENE, help=f"빌드 시 메인 씬 (기본 {DEFAULT_SCENE})")
    ap.add_argument("--no-build", action="store_true", help="빌드 건너뜀")
    ap.add_argument("--no-install", action="store_true", help="설치 건너뜀")
    ap.add_argument("--no-launch", action="store_true", help="실행 건너뜀")
    ap.add_argument("--no-logs", action="store_true", help="로그 스트림 생략")
    args = ap.parse_args()

    adb: str = _resolve_adb()
    target: str | None = None

    if not args.no_build:
        build(args.scene)
    if not args.no_install:
        target = install(adb)
    if not args.no_launch:
        launch(adb, target)
    if not args.no_logs:
        stream_logs(adb, target)
    return 0


if __name__ == "__main__":
    sys.exit(main())
