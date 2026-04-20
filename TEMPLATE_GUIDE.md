# Godot 증분 시뮬레이터 템플릿 — Foundation Guide

이 리포의 **특정 git tag 상태가 곧 템플릿**입니다. 별도 template 리포를 만들지 않고 tag·가이드·체크리스트만으로 재사용을 성립시키는 **최소 작업 전략**.

- **현재 상태**: `tools/preparation_check.gd` 42 READY / 18 PLANNED / 0 MISSING
- **권장 tag 이름**: `template-foundation-v1`
- **대상 Godot 버전**: 4.6.2 (standard)

---

## 1. "현재 상태를 고정(lock)"하는 법

추가 파일 이동·복사·리포 분리 없이 **git tag 하나**로 완결. 락 수립 절차:

```bash
# 1) 현재 미커밋 변경사항을 하나의 foundation 커밋으로 묶음
git add star-reach/ .claude/ CLAUDE.md study/ TEMPLATE_GUIDE.md NEW_GAME_QUICKSTART.md
git commit -m "foundation: incremental sim template v1 (UI+Resources+Scenes+IAP+CoreSystems)"

# 2) 템플릿 tag 부여 (이 해시가 영구 기준점)
git tag -a template-foundation-v1 -m "42 READY infra: 5-axis prep check green"

# 3) (선택) GitHub 등 remote에 push
git push origin main
git push origin template-foundation-v1
```

이후:
- **StarReach 개발은 `main` 브랜치에서 계속 진행** (tag는 움직이지 않음)
- **템플릿이 더 성숙하면** `template-foundation-v2`로 새 tag 발급 (기존 tag는 그대로 보존)

---

## 2. 새 증분 게임을 이 템플릿으로 시작하는 법

### 2.1 최소 절차 (5분)

```bash
# 1) 템플릿 기준점을 복제
git clone https://github.com/<your-org>/godot-star-reach godot-<new-game>
cd godot-<new-game>

# 2) 템플릿 tag로 체크아웃 + 새 브랜치
git checkout template-foundation-v1 -b main
git remote rename origin template-source    # 원본을 remote로 보존
# (필요 시 새 origin을 여기서 설정)

# 3) 프로젝트 폴더 리네임 (선택)
git mv star-reach <new-game>
# → project.godot 경로 참조는 상대경로라 수정 불필요

# 4) 커스터마이즈 (아래 §3 참조)
```

### 2.2 헤드리스로 준비 상태 재확인

```bash
# 새 프로젝트 최초 1회 (class_name cache 채우기)
"<godot-path>" --path <new-game> --editor --headless --quit-after 4

# 3개 준비 점검
"<godot-path>" --path <new-game> --headless --script res://tools/preparation_check.gd
"<godot-path>" --path <new-game> --headless --script res://tools/iap_preparation_check.gd
"<godot-path>" --path <new-game> --headless --script res://tools/smoke_test.gd
```

세 개 모두 `exit 0` → **새 게임 개발 착수 가능 상태**.

---

## 3. 고정(frozen) vs 커스터마이즈 영역

### 3.1 ❄️ FROZEN — 건드리지 않음 (게임 불가지 인프라)

| 경로 | 역할 |
|---|---|
| `scripts/iap/*.gd` | IAP 3-플랫폼 추상화 (Mock/Android/iOS/Steam backend) |
| `scripts/iap/README.md` | 재사용 가이드 |
| `scripts/resources/iap_product.gd` | IAPProduct Custom Resource 스키마 |
| `scripts/resources/cost_curve.gd` | @abstract 비용 곡선 Strategy 베이스 |
| `scripts/resources/exponential_cost.gd` | 기본 비용 곡선 구현체 |
| `scripts/resources/currency_def.gd` | 재화 정의 스키마 |
| `scripts/resources/generator_def.gd` | 생성기 정의 스키마 |
| `scripts/autoload/event_bus.gd` | signal-only 허브 |
| `scripts/autoload/time_manager.gd` | 틱 소스 + 속도 배율 |
| `scripts/autoload/iap_service.gd` | OS 분기 + 카탈로그 + Mock 폴백 |
| `scenes/common/confirm_dialog.{tscn,gd}` | 재사용 모달 |
| `scenes/common/currency_counter.{tscn,gd}` | 재사용 HUD 카운터 |
| `addons/GodotGooglePlayBilling/` | Android 결제 플러그인 |
| `addons/godotsteam/` | Steam GDExtension |
| `ios/plugins/ios-in-app-purchase/` | iOS 결제 플러그인 |
| `android/build/` | Android Gradle 빌드 템플릿 |
| `tools/smoke_test.gd` | 파일 무결성 검사 |
| `tools/preparation_check.gd` | 5축 준비 점검 |
| `tools/iap_preparation_check.gd` | IAP 전용 딥체크 |

이 영역은 **템플릿 업그레이드 시에만** 갱신. 게임별 차이는 아래 §3.2로.

### 3.2 🎨 CUSTOMIZE — 게임마다 바꾸는 것

| 경로 | 필수 변경 | 변경 내용 |
|---|---|---|
| `project.godot` `config/name` | ✅ | `"StarReach"` → `"<New Game>"` |
| `project.godot` `boot_splash/bg_color` | 권장 | 브랜드 색 |
| `steam_appid.txt` | 출시 시 | `480` → 실제 Steam AppID |
| `scenes/splash/splash.tscn` Title 라벨 | ✅ | 게임 이름 |
| `scenes/main_menu/main_menu.tscn` Title 라벨 | ✅ | 게임 이름 |
| `data/currencies/*.tres` | ✅ | 재화 종류/이름/초기값 |
| `data/generators/*.tres` | ✅ | 생성기 밸런싱 |
| `data/iap/*.tres` | ✅ | 상품 SKU·가격·grants 페이로드 |
| `scripts/autoload/game_state.gd` `GENERATOR_PATHS` / `CURRENCY_PATHS` | ✅ | 위에서 바꾼 `.tres` 경로 반영 |
| `scripts/autoload/game_state.gd` `_on_iap_purchase_completed` grants 해석 | 게임마다 | 예: `"currency"`, `"flags"` 외에 `"unlock"`, `"bonus"` 등 |
| `scripts/autoload/event_bus.gd` 추가 signal | 게임마다 | 해당 게임의 도메인 이벤트 |
| `scenes/game/panels/*.tscn` | 게임마다 | 업그레이드/프레스티지 UI 등 |

### 3.3 🗑️ DELETE — 새 게임에서 제거할 StarReach 잔재

- `scenes/tetris/` — 테트리스 실험 씬 (github pages 데모용)
- `main.tscn` — 미사용 더미 (splash가 main_scene)
- `tools/android_test.py`, `tools/web_test.py` — StarReach 배포 스크립트

---

## 4. 새 게임 체크리스트 (`NEW_GAME_QUICKSTART.md`의 축약본)

```
[ ] 0. template-foundation-v1 tag로 checkout + 새 브랜치
[ ] 1. project.godot의 config/name 교체
[ ] 2. 스플래시·메인메뉴의 Title 라벨 교체
[ ] 3. data/currencies/ 에 게임 재화 .tres 작성
[ ] 4. data/generators/ 에 생성기 .tres 작성 (최소 2종)
[ ] 5. game_state.gd의 CURRENCY_PATHS / GENERATOR_PATHS 갱신
[ ] 6. data/iap/ 에 상품 .tres 작성 (가격·grants)
[ ] 7. StarReach 잔재 삭제 (scenes/tetris/, main.tscn, tools/*.py)
[ ] 8. --editor --headless --quit-after 4 (class_name 캐시)
[ ] 9. preparation_check → 42 READY 확인
[ ] 10. F5로 splash → main_menu → game → Shop 흐름 검증
```

---

## 5. 템플릿 채택 이후 개발 로드맵

PLANNED 18 항목을 이 순서로 열어가세요.

### Phase 1.5 — SaveSystem (첫 실제 유저 대응)
- `scripts/autoload/save_system.gd` — `user://savegame.json` + 버전 마이그레이션
- `GameState.to_dict()` / `from_dict()` 패턴
- N초 주기 저장 + `NOTIFICATION_WM_CLOSE_REQUEST` + 수동 저장
- `CLAUDE.md §저장 시스템` 스펙 참조

### Phase 1.6 — Offline Progress
- `TimeManager.apply_offline_progress(last_unix)` — 최대 8h 캡
- 로드 직후 `advance_simulation(capped_delta)` 적용
- "오프라인 중 획득" 요약 모달

### Phase 2 — Upgrades / Prestige
- `scripts/resources/upgrade_def.gd` Custom Resource
- `data/upgrades/*.tres` 밸런싱
- `scenes/game/panels/upgrade_panel.gd` 실구현
- 프레스티지 계산 + 리셋 흐름 + 영구 보너스

### Phase 3 — Directors (자산 연동)
- `AssetHub` 오토로드 — UI 아이콘/폰트 매니페스트
- `SfxDirector` — 사운드 이벤트 바인딩 + 풀링
- `FxDirector` — 파티클 스폰 팩토리
- 이진 자산이 실제로 생길 때 도입

### Phase 4 — 실제 플랫폼 결제 활성화
- 4.1 Android: Play Console $25 + SKU 등록 + Internal Testing
- 4.2 iOS: Apple Developer $99 + App Store Connect + Xcode 빌드 환경
- 4.3 Steam: Steamworks Partner $100 + DLC/MTX 서버

### Phase 5 — 출시 준비
- i18n: `.po` 파일 + `TranslationServer`
- 자산 임포트 정규화 스크립트
- Safe area wrapper 실기기 검증
- Logger 유틸
- NumberFormatter 유틸

---

## 6. 템플릿 상태 검증 (언제든지)

```bash
# 3개 tool 모두 exit 0 이어야 foundation intact
godot --path <project> --headless --script res://tools/preparation_check.gd        # 42 READY
godot --path <project> --headless --script res://tools/iap_preparation_check.gd    # 27 / 27
godot --path <project> --headless --script res://tools/smoke_test.gd               # 13+14+7 OK
```

하나라도 실패 → foundation이 손상됐다는 신호. `git diff template-foundation-v1` 로 차이 확인.

---

## 7. 템플릿 진화 정책

- **패치 업그레이드** (버그 fix, 1.5/2/3 Phase 흡수): 새 tag `template-foundation-v2` 발급. 기존 v1 게임은 선택적 merge.
- **프레임워크 호환성 breakage** (Godot 메이저 업): 새 tag + 마이그레이션 가이드 별도 문서.
- **게임별 변경이 템플릿으로 역류(backport)되어야 할 때**: 해당 변경을 main으로 cherry-pick 후 v2 tag 재발급.

템플릿 == 리포의 특정 tag라는 구조 덕에 **별도 repo 없이도 버전 관리**가 가능.

---

## 8. 참고 문서

- `star-reach/CLAUDE.md` — 코드/씬 규칙
- `CLAUDE.md` (루트) — 장르 규범 + 에이전트 워크플로우
- `star-reach/scripts/iap/README.md` — IAP 모듈 재사용 가이드
- `star-reach/addons/INSTALL_STATUS.md` — 플러그인 설치 상태
- `study/*.md` — 설계 결정 기록
