# New Incremental Sim — 5분 Quickstart

이 리포의 `template-foundation-v1` tag를 기준으로 **새 증분 게임 프로젝트를 시작**하는 최단 절차. 상세는 [`TEMPLATE_GUIDE.md`](./TEMPLATE_GUIDE.md) 참조.

---

## 0. 준비물
- Godot 4.6.2 standard 에디터 (PATH 또는 절대경로)
- Git
- (선택) Android SDK, Xcode(macOS), Steam 클라이언트 — 실 결제 검증 시

## 1. 템플릿 복제
```bash
git clone <template-repo> my-new-game
cd my-new-game
git checkout template-foundation-v1 -b main
```

## 2. StarReach 잔재 제거
```bash
rm -rf star-reach/scenes/tetris
rm -f  star-reach/main.tscn
rm -f  star-reach/tools/android_test.py star-reach/tools/web_test.py
```
(원한다면 `git mv star-reach my-new-game` 으로 폴더명도 교체)

## 3. 프로젝트 이름 교체 (3곳)
```bash
# 3-1. project.godot
# config/name="StarReach" → "<My New Game>"

# 3-2. scenes/splash/splash.tscn — Title 라벨 text
# text = "StarReach" → "<My New Game>"

# 3-3. scenes/main_menu/main_menu.tscn — Title 라벨 text
# text = "StarReach" → "<My New Game>"
```

## 4. 게임 데이터 교체
- `data/currencies/<new>.tres` — 새 재화 정의
- `data/generators/<gen1>.tres`, `<gen2>.tres` — 생성기 2종 이상
- `data/iap/*.tres` — 상품 SKU·가격·grants 조정
- `scripts/autoload/game_state.gd` → `CURRENCY_PATHS` / `GENERATOR_PATHS` 에 위 경로 반영

## 5. `class_name` 캐시 초기화
```bash
"<godot>" --path . --editor --headless --quit-after 4
```

## 6. 준비 상태 3종 점검
```bash
"<godot>" --path . --headless --script res://tools/preparation_check.gd
"<godot>" --path . --headless --script res://tools/iap_preparation_check.gd
"<godot>" --path . --headless --script res://tools/smoke_test.gd
```
세 개 모두 `exit 0` 이면 기반 완성. F5로 splash → menu → game → Shop 동선 검증.

## 7. 첫 커밋
```bash
git add -A
git commit -m "init: fork from template-foundation-v1"
```

## 이후 개발 순서
`TEMPLATE_GUIDE.md §5` 로드맵:
1. Phase 1.5 SaveSystem
2. Phase 1.6 Offline progress
3. Phase 2 Upgrades / Prestige
4. Phase 3 Directors (자산 많아지면)
5. Phase 4 실플랫폼 결제 활성화
6. Phase 5 출시 준비 (i18n, SafeArea, Logger)
