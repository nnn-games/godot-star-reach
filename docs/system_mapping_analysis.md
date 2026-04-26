# 🔬 시스템 아키텍처 개요 — Godot 4.6

> **문서 유형**: 시스템 아키텍처 개요
> **작성일**: 2026-04-24
> **참조 기획**: `docs/game_concept_rocket_launch.md`, `docs/prd.md`
> **분석 대상**: 29개 시스템 카탈로그 (`docs/systems/INDEX.md`) + Godot 4.6 프로젝트 구조

---

## 1. 문서 목적

본 문서는 Star Reach의 **Godot 4.6 단일 코드베이스 + 싱글 오프라인 + Mobile / PC Steam 동시 출시** 아키텍처를 시스템 카탈로그 단위로 정리한다. 각 시스템의 책임 / 구현 위치 / 핵심 자료구조 / 의존 관계를 한 자리에서 본다.

---

## 2. 아키텍처 골격

| 영역 | 선택 |
|---|---|
| **실행 모델** | 단일 클라이언트 (싱글 오프라인) |
| **언어** | GDScript |
| **DI / 서비스** | Godot **Autoload 싱글톤** + 서비스 노드 |
| **이벤트** | Godot **Signal** + `EventBus` 오토로드 |
| **데이터 영속** | 로컬 `user://savegame.json` + V2 클라우드 동기화 옵션 |
| **데이터 정의** | `Resource` (`.tres`) + `class_name` |
| **씬 / 월드** | `*.tscn` Scene 트리 |
| **UI** | `Control` + `CanvasLayer` + `*.tscn` |
| **연출** | `Tween` / `AnimationPlayer`, 2D `ParallaxBackground` + `CanvasModulate`, `VideoStreamPlayer` (사전 렌더 영상) |
| **결제** | Google Play Billing (Android) / Apple StoreKit (iOS) / GodotSteam (PC) |
| **광고** | AdMob (Godot plugin) — 모바일 한정 |
| **세이브 트리거** | `_notification(NOTIFICATION_WM_CLOSE_REQUEST)` + 10s 주기 + 수동 |
| **빌드 산출** | Android APK/AAB / iOS IPA / Windows Steam EXE / Linux Steam (Deck 호환) |

---

## 3. 시스템별 매핑

8 카테고리 / 29 시스템 카탈로그(`docs/systems/INDEX.md`)의 Godot 구현 위치 정리.

### 3.1 카테고리 1 — Launch Core

| 시스템 | Godot 구현 |
|---|---|
| LaunchSession | `scripts/services/launch_session_service.gd` (Autoload) |
| Multi-Stage Probability | `scripts/services/launch_service.gd` + `data/launch_balance_config.tres` |
| Auto Launch + Offline Progress | `scripts/services/auto_launch_service.gd`, `scripts/services/offline_progress_service.gd` |
| Stress / Overload / Abort | `scripts/services/stress_service.gd` + `data/stress_config.tres` |

**핵심 동작**: 메인 화면 LAUNCH 탭 → `LaunchService`가 단계별 확률 판정 → `EventBus.stage_succeeded/stage_failed` 시그널 발화 → UI / VFX / Audio가 자체 구독.

### 3.2 카테고리 2 — Progression

| 시스템 | Godot 구현 |
|---|---|
| Destination | `scripts/services/destination_service.gd` + `data/destination_config.tres` |
| Region | `data/region_config.tres` + `data/region_mastery_config.tres` |
| Program Lv. (TechLevel) | `GameState.tech_level` (Autoload 변수) |
| Launch Tech (5종) | `scripts/services/launch_tech_service.gd` + `data/launch_tech_config.tres` |
| Facility Upgrades (5종) | `scripts/services/facility_upgrade_service.gd` + `data/facility_upgrade_config.tres` |

### 3.3 카테고리 3 — Economy

| 시스템 | Godot 구현 |
|---|---|
| Currency (XP / Credit / TechLevel) | `scripts/autoload/game_state.gd` |
| Destination Reward | `destination_service.gd::complete_destination()` — 단일 시그널 페이로드로 모든 보상 fanout |

### 3.4 카테고리 4 — Cinematic / Visual

| 시스템 | Godot 구현 |
|---|---|
| Main Scene Cinematic | `scripts/services/main_scene_controller.gd` + `scripts/util/screen_shake.gd` (`Camera2D.zoom` + shake 헬퍼) |
| Sky / Lighting Transition | `scripts/services/sky_profile_applier.gd` + `data/sky_profiles/*.tres` (`ParallaxBackground` + `CanvasModulate`) |
| Launch VFX / Result Overlay | `scenes/launch/launch_vfx.tscn` (`GPUParticles2D` 4종 프리셋) + `scenes/transitions/milestone_video_overlay.tscn` (`VideoStreamPlayer` + `.ogv`) |

### 3.5 카테고리 5 — Meta / Collection

| 시스템 | Godot 구현 |
|---|---|
| Discovery / Codex | `scripts/services/discovery_service.gd` + `data/codex_config.tres` (12 엔트리 Lite B) |
| Badge | `scripts/services/badge_service.gd` + `data/badge_config.tres` (Steam Achievements / Google Play Games / iOS Game Center 매핑) |
| Mission | `scripts/services/mission_service.gd` + `data/mission_config.tres` (일일 / 주간) |
| Best Records | `scripts/services/best_records_service.gd` (로컬 베스트, V2 외부 리더보드 옵션) |

### 3.6 카테고리 6 — Meta Bonus (싱글 리텐션)

| 시스템 | Godot 구현 |
|---|---|
| Meta Bonus (Daily Login / Codex / Playtime / Rating Modal) | `scripts/services/meta_bonus_service.gd` + `data/meta_bonus_config.tres` |
| Season Collection (분기별 코스메틱) | `scripts/services/season_service.gd` + `data/season_collection_config.tres` |

### 3.7 카테고리 7 — Monetization

| 채널 | Godot 구현 |
|---|---|
| 영구 IAP (`IAP_VIP`, `IAP_AUTO_LAUNCH_PASS`, `IAP_GUIDANCE_MODULE`) | `scripts/services/iap_service.gd` + 플랫폼 어댑터 + `data/iap_config.tres` |
| 소모 IAP (`IAP_BOOST_2X`, `IAP_TRAJECTORY_SURGE`, `IAP_AUTO_FUEL`, `IAP_SHIELD_T3/T4/T5`, `IAP_SYSTEM_PURGE`, `IAP_CREDIT_S/M/L`) | 위와 동일 |
| Steam DLC (`DLC_INTERSTELLAR_FRONTIER`, Cosmetic DLC, OST/Artbook) | `scripts/services/dlc_service.gd` + `data/dlc_config.tres` (GodotSteam `Steam.isDLCInstalled()`) |
| Daily Reward / Mission | `scripts/services/daily_reward_service.gd`, `scripts/services/daily_mission_service.gd` |
| Rewarded Ad (모바일 한정) | `scripts/services/ad_reward_service.gd` (AdMob 플러그인 래퍼) |
| Subscription (`Orbital Operations Pass`, $4.99/월) | `scripts/services/subscription_service.gd` + `data/subscription_config.tres` |
| Battle Pass (시즌 50 티어) | `scripts/services/battle_pass_service.gd` + `data/battle_pass_config.tres` |

### 3.8 카테고리 8 — Shell / Platform

| 시스템 | Godot 구현 |
|---|---|
| SaveSystem | `scripts/autoload/save_system.gd` + `scripts/autoload/game_state.gd` |
| EventBus (메시지 버스) | `scripts/autoload/event_bus.gd` |
| Autoload 부팅 | `project.godot` `[autoload]` 섹션 (등록 순서 = 부팅 순서) |
| UI Shell | `scenes/main/main_screen.tscn` + `scenes/ui/global_hud.tscn` + `scripts/services/player_state_service.gd` |
| TelemetryService | `scripts/services/telemetry_service.gd` (로컬 + Steam User Stats / GPG Events / Firebase Analytics 옵션) |

---

## 4. 신규 아키텍처 요소 (Godot 단일 코드베이스 전제)

### 4.1 Autoload 싱글톤 등록 (project.godot)

```
[autoload]
EventBus="*res://scripts/autoload/event_bus.gd"
GameState="*res://scripts/autoload/game_state.gd"
SaveSystem="*res://scripts/autoload/save_system.gd"
```

### 4.2 EventBus 시그널 정의

`scripts/autoload/event_bus.gd`:

```gdscript
extends Node

# Launch
signal launch_started
signal stage_succeeded(stage_index: int, chance: float)
signal stage_failed(stage_index: int, chance: float)
signal launch_completed(destination_id: String)
signal cinematic_state_changed(state: String)

# Progression
signal destination_completed(destination_id: String, reward: Dictionary)
signal region_first_visited(region_id: String)
signal region_mastery_level_up(region_id: String, level: int)

# Codex / Badge
signal codex_entry_unlocked(entry_id: String)
signal codex_entry_updated(entry_id: String)
signal codex_section_unlocked(entry_id: String, section_id: String)
signal codex_entry_completed(entry_id: String)
signal badge_awarded(badge_id: String)

# Economy
signal currency_changed(currency_type: String, new_value: int)
signal upgrade_purchased(category: String, item_id: String)

# Stress / Risk
signal stress_changed(new_value: float)
signal abort_triggered(repair_cost: int)

# Monetization
signal iap_purchased(product_id: String, transaction_id: String)
signal iap_consumed(product_id: String)
signal subscription_renewed(expire_at: int)
signal battle_pass_tier_unlocked(tier: int, track: String)

# UI Lock
signal input_lock_acquired(reason: String)
signal input_lock_released(reason: String)
```

### 4.3 SaveSystem 스키마 (`user://savegame.json`)

```gdscript
const SAVE_SCHEMA_VERSION := 1
const SAVE_PATH := "user://savegame.json"

# GameState 직렬화 → JSON
{
    "version": 1,
    "saved_at": 1714000000,                         # Time.get_unix_time_from_system()
    "currency": { "xp": 0, "credit": 0, "tech_level": 0 },
    "progression": {
        "current_destination_id": "D_01",
        "highest_completed_tier": 0,
        "cleared_tiers": [],
        "completed_destinations": []
    },
    "stress": { "value": 0, "last_decay_at": 0 },
    "auto_launch": { "enabled": false, "rate": 1.0 },
    "iap": {
        "non_consumable": [],
        "consumable_log": [],
        "active_boosts": {},
        "shield_inventory": {},
        "purge_inventory": 0
    },
    "subscription": { "active": false, "expire_at": 0 },
    "daily_reward": { "last_claim_date": "", "streak": 0, "claimed_today": false },
    "daily_mission": { "date": "", "missions": [], "daily_tech_level_earned": 0 },
    "season": { "current_season_id": "", "season_xp": 0, "current_tier": 0 },
    "battle_pass": { "premium_owned": false, "claimed_tiers_free": [], "claimed_tiers_premium": [] },
    "meta_bonus": {
        "title_owned": [], "title_equipped": "",
        "cosmetics_owned": [], "cosmetics_equipped": {},
        "playtime_milestones_claimed": [],
        "codex_milestones_claimed": [],
        "region_mastery_claimed": [],
        "first_arrival_milestones_claimed": [],
        "rating_modal_shown": false
    },
    "ad_reward_state": { "date": "", "counts": {} },
    "discovery": { "entries": {}, "viewed_entries": [] },
    "badges": { "unlocked": [] },
    "best_records": { "total_wins": 0, "highest_tech_level": 0, "best_tier": 0 },
    "settings": {
        "sfx_volume": 1.0, "bgm_volume": 1.0,
        "auto_skip_cinematics": false,
        "language": "ko"
    },
    "total_play_time_sec": 0,
    "rng_seed": 0,
    "seen_cinematics": []
}
```

### 4.4 Resource (`.tres`) 정의 패턴

```gdscript
# data/launch_balance_config.tres 의 기반 클래스
class_name LaunchBalanceConfig extends Resource

@export var tier_segments: Array[TierSegment] = []

# data/tier_segment.tres 의 기반 클래스
class_name TierSegment extends Resource

@export var tier: int = 1
@export var stage_range: Vector2i = Vector2i(1, 4)
@export_range(0.0, 1.0) var base_chance: float = 0.5
@export_range(0.0, 1.0) var max_chance: float = 0.85
```

기획자가 Godot 에디터의 Inspector에서 직접 `.tres` 파일을 편집 가능. 코드 수정 없이 밸런스 튜닝 가능.

---

## 5. 플랫폼별 어댑터

핵심 게임 로직은 단일 코드베이스로 100% 공유. 플랫폼별로 분리되는 것은 아래 어댑터 레이어뿐.

### 5.1 결제 (IAP)

| 플랫폼 | 플러그인 | 영수증 검증 |
|---|---|---|
| Android | `godot-android-plugin-google-play-billing` (또는 직접 GDExtension) | Google Play Billing 클라이언트 영수증 + `acknowledgePurchase()` |
| iOS | `godot-ios-plugins` (`inappstore` 모듈) | StoreKit 영수증 (Base64) — 클라이언트 검증 또는 옵션으로 Apple `verifyReceipt` |
| Steam | `addons/godotsteam` (`Steam.purchaseStart()`) | Steam 영수증 (Steamworks SDK) |

공통 인터페이스: `scripts/services/iap_service.gd`가 베이스, `_iap_adapter_*.gd`가 플랫폼별 구현.

### 5.2 광고 (모바일 한정)

| 플랫폼 | 플러그인 |
|---|---|
| Android / iOS | `godot-admob` 플러그인 (Rewarded Video Ad) |
| Steam | (광고 없음 — PC 게이머 문화) |

### 5.3 실적 (Achievements)

| 플랫폼 | API |
|---|---|
| Android | Google Play Games Achievements (`godot-google-play-games` 플러그인) |
| iOS | Apple Game Center (`godot-ios-plugins` Game Center 모듈) |
| Steam | Steam Achievements (`Steam.setAchievement()`) |

공통 인터페이스: `scripts/services/badge_service.gd`가 `achievement_id`로 플랫폼별 매핑.

### 5.4 클라우드 세이브 (V2)

| 플랫폼 | API |
|---|---|
| Android | Google Play Games Saved Games |
| iOS | iCloud Key-Value Store |
| Steam | Steam Cloud (Steamworks Build Settings → Auto-Cloud `*.json`) |

V1은 로컬 단독. V2에서 동기화 추가.

---

## 6. 우선 구현 (Phase 1~7 매핑)

`docs/plan.md` Phase와 1:1 동기화.

| Phase | Godot 산출물 |
|---|---|
| **P1 (1~2주)** | `LaunchService` + `LaunchSessionService` + `data/launch_balance_config.tres` + `EventBus` |
| **P2 (3~4주)** | `StressService` + 구간형 확률 상한 + Pity System |
| **P3 (5~6주)** | `SkyProfileApplier` + `data/sky_profiles/*.tres` + `ParallaxBackground` + 사전 렌더 영상 5종 |
| **P4 (7~8주)** | `AutoLaunchService` + `OfflineProgressService` + `DiscoveryService` + `BadgeService` + `MissionService` |
| **P5 (9~10주)** | `MainScreen.tscn` + `UpgradePanel.tscn` + `CodexPanel.tscn` + 사운드 |
| **P6 (11~12주)** | `IAPService` + Google Play Billing / StoreKit / GodotSteam + `daily_reward_service.gd` + `subscription_service.gd` + AdMob |
| **P7 (13~14주)** | 밸런스 QA + 다국어 (한/영) + 출시 제출 |

---

## 7. 관련 문서

- `docs/systems/INDEX.md` — 시스템 카탈로그 (29 시스템 / 8 카테고리)
- `docs/systems/ARCHITECTURE.md` — Mermaid 다이어그램
- `docs/prd.md` — PRD
- `docs/plan.md` — 14주 개발 로드맵
- `docs/flow.md` — 게임 흐름 (Godot 씬 매핑)
- `docs/bm.md` — IAP / DLC 채널 사양
- `docs/social_bm.md` — 메타 보너스 (싱글 리텐션)
- `CLAUDE.md` (루트) — Agent-Driven 워크플로우
- `star-reach/CLAUDE.md` — Godot 내부 코드/씬 규칙
