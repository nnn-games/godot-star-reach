"""Build Web export, serve with COOP/COEP headers, open browser — one shot.

사용 예:
    python tools/web_test.py                    # 테트리스 씬을 메인으로 빌드 후 서빙
    python tools/web_test.py --scene res://main.tscn
    python tools/web_test.py --no-build         # 기존 build/web 을 서빙만
    python tools/web_test.py --port 9000
    python tools/web_test.py --no-open          # 브라우저 자동 오픈 끔

환경변수:
    GODOT_BIN  Godot 실행파일 경로 (기본: C:\\Godot\\Godot_v4.6.2-stable_win64.exe)

사전조건:
    1. Godot 에디터에서 Project → Export → Add → Web 프리셋을 만들어 두어야 함 (이름: "Web")
    2. Web export template 설치 완료 상태여야 함
"""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import threading
import webbrowser
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

PROJECT_DIR: Path = Path(__file__).resolve().parents[1]
BUILD_DIR: Path = PROJECT_DIR / "build" / "web"
OUTPUT_HTML: Path = BUILD_DIR / "index.html"
PROJECT_FILE: Path = PROJECT_DIR / "project.godot"
EXPORT_PRESETS: Path = PROJECT_DIR / "export_presets.cfg"
DEFAULT_SCENE: str = "res://scenes/splash/splash.tscn"
PRESET_NAME: str = "Web"

GODOT_BIN: str = os.environ.get(
    "GODOT_BIN",
    r"C:\Godot\Godot_v4.6.2-stable_win64.exe",
)

MAIN_SCENE_RE = re.compile(r'run/main_scene="([^"]+)"')


class CoopCoepHandler(SimpleHTTPRequestHandler):
    def end_headers(self) -> None:
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "cross-origin")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, fmt: str, *args: object) -> None:
        sys.stderr.write(f"[http] {self.address_string()} {fmt % args}\n")


def _check_preconditions() -> None:
    if not Path(GODOT_BIN).exists():
        sys.exit(f"[err] Godot 실행파일을 찾을 수 없습니다: {GODOT_BIN}\n"
                 f"      GODOT_BIN 환경변수로 경로를 지정하세요.")
    if not EXPORT_PRESETS.exists():
        sys.exit(f"[err] {EXPORT_PRESETS} 없음.\n"
                 f"      에디터 Project → Export 에서 'Web' 프리셋을 먼저 추가하세요.")
    preset_text: str = EXPORT_PRESETS.read_text(encoding="utf-8")
    if f'name="{PRESET_NAME}"' not in preset_text:
        sys.exit(f"[err] export_presets.cfg 에 '{PRESET_NAME}' 프리셋이 없습니다.")


def _swap_main_scene(target: str) -> str:
    """project.godot 의 run/main_scene 을 target 으로 바꾸고 원래 값을 반환."""
    text: str = PROJECT_FILE.read_text(encoding="utf-8")
    match = MAIN_SCENE_RE.search(text)
    if not match:
        sys.exit("[err] project.godot 에 run/main_scene 항목이 없습니다.")
    original: str = match.group(1)
    if original == target:
        return original
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
            "--export-release", PRESET_NAME,
            str(OUTPUT_HTML),
        ]
        print(f"[build] {' '.join(cmd)}")
        result = subprocess.run(cmd, capture_output=False)
        if result.returncode != 0:
            sys.exit(f"[err] Godot 내보내기 실패 (exit {result.returncode})")
        if not OUTPUT_HTML.exists():
            sys.exit(f"[err] 빌드는 성공했지만 {OUTPUT_HTML} 가 생성되지 않았습니다.")
        print(f"[build] OK → {OUTPUT_HTML}")
    finally:
        _swap_main_scene(original)
        print(f"[build] main_scene 복구 → {original}")


def serve(port: int, open_browser: bool) -> None:
    if not OUTPUT_HTML.exists():
        sys.exit(f"[err] {OUTPUT_HTML} 가 없습니다. --no-build 없이 먼저 빌드하세요.")
    os.chdir(BUILD_DIR)
    server = ThreadingHTTPServer(("127.0.0.1", port), CoopCoepHandler)
    url: str = f"http://127.0.0.1:{port}/"
    print(f"[serve] {url}  (Ctrl+C 로 종료)")
    if open_browser:
        threading.Timer(0.8, lambda: webbrowser.open(url)).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[serve] stopped.")
    finally:
        server.server_close()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--scene", default=DEFAULT_SCENE, help=f"빌드 시 메인 씬 (기본: {DEFAULT_SCENE})")
    ap.add_argument("--no-build", action="store_true", help="빌드 건너뛰고 서빙만")
    ap.add_argument("--port", type=int, default=8060)
    ap.add_argument("--no-open", action="store_true", help="브라우저 자동 오픈 끔")
    args = ap.parse_args()

    if not args.no_build:
        build(args.scene)
    serve(args.port, open_browser=not args.no_open)
    return 0


if __name__ == "__main__":
    sys.exit(main())
