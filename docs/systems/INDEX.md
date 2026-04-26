# Star Reach System Architecture — Index

> 작성일: 2026-04-24
> 문서 유형: 시스템 카탈로그 (코어 로직 / 데이터 분리)
> 기준: `docs/*.md` 정본 기획 + Godot 4.6 GDScript 코드베이스
> 목적: 게임을 구성하는 핵심 시스템을 카테고리별로 분류하고, 각 시스템에 대해 **코어 로직**(행동/상태머신/공식)과 **데이터**(정적 Config / 영속 SaveSystem JSON / 런타임 상태)를 분리해 단일 레퍼런스로 제공한다.

> 📊 **전체 시스템 시각화 다이어그램**: [`ARCHITECTURE.md`](./ARCHITECTURE.md) — Godot 단일 클라이언트 기준 11가지 관점의 Mermaid 다이어그램 (카테고리 뷰 / Autoload 의존성 / 발사 시퀀스 / 팬아웃 / 3화폐 흐름 / EventBus 시그널 맵 / SaveSystem JSON 스키마 / 클라이언트 상태머신 / 플랫폼 빌드 매트릭스 / IAP 플로우 / SaveSystem 마이그레이션)

---

## 카탈로그 (8 대분류 / 29 세부 시스템)

### 1. Launch Core
| ID | 시스템 | 정본 문서 참조 | Godot 매핑 |
|---|---|---|---|
| [1-1](./1-1-launch-session.md) | LaunchSession (메인 화면 발사 컨텍스트) | `rocket_launch_implementation_spec §1, §3, §4`, `prd §3` | `scripts/services/launch_session_service.gd` |
| [1-2](./1-2-multi-stage-probability.md) | Multi-Stage Probability (N단계 확률 판정) | `launch_balance_design` | `scripts/services/launch_service.gd`, `data/launch_balance_config.tres` |
| [1-3](./1-3-auto-launch.md) | Auto Launch (자동 발사 + 오프라인 진행) | `bm §3.1`, `post_landing_bm_plan §2.1, §5` | `scripts/services/auto_launch_service.gd`, `scripts/services/offline_progress_service.gd` |
| [1-4](./1-4-stress-abort.md) | Stress / Overload / Abort | `post_landing_bm_plan §6~7`, `game_term_alignment_review §6.3` | `scripts/services/stress_service.gd`, `data/stress_config.tres` |

### 2. Progression
| ID | 시스템 | 정본 문서 참조 | Godot 매핑 |
|---|---|---|---|
| [2-1](./2-1-destination.md) | Destination (100목적지/선택/해금) | `destination_config`, `contents` | `scripts/services/destination_service.gd`, `data/destination_config.tres` |
| [2-2](./2-2-region.md) | Region (11 지역 첫도달 뱃지/마스터리) | `destination_config §5`, `celestial_codex_design_plan §10.4` | `data/region_config.tres`, `data/region_mastery_config.tres` |
| [2-3](./2-3-program-level.md) | Program Lv. (TechLevel 해금 축) | `game_term_alignment_review §6.2` | `GameState.tech_level` (Autoload) |
| [2-4](./2-4-launch-tech.md) | Launch Tech (세션 5종) | `prd §11.2`, `game_term_alignment_review` | `scripts/services/launch_tech_service.gd`, `data/launch_tech_config.tres` |
| [2-5](./2-5-facility-upgrades.md) | Facility Upgrades (영구 5종) | `prd §11.3`, `game_term_alignment_review` | `scripts/services/facility_upgrade_service.gd`, `data/facility_upgrade_config.tres` |

### 3. Economy
| ID | 시스템 | 정본 문서 참조 | Godot 매핑 |
|---|---|---|---|
| [3-1](./3-1-currency.md) | Currency (XP / Credit / TechLevel) | `game_term_alignment_review §6.2`, `post_landing_bm_plan §3` | `scripts/autoload/game_state.gd` |
| [3-2](./3-2-destination-reward.md) | Destination Reward (클리어 보상 지급) | `destination_config §9`, `post_landing_bm_plan §3` | `destination_service.gd::complete_destination()` |

### 4. Cinematic / Visual
| ID | 시스템 | 정본 문서 참조 | Godot 매핑 |
|---|---|---|---|
| [4-1](./4-1-seat-cinematic.md) | Main Scene Cinematic (`Camera2D` zoom + shake + Sprite2D Tween) | `rocket_launch_implementation_spec §6` | `scripts/services/main_scene_controller.gd`, `scripts/util/screen_shake.gd` |
| [4-2](./4-2-sky-transition.md) | Sky / Lighting Transition (`ParallaxBackground` + `CanvasModulate`) | `rocket_launch_implementation_spec §7`, `launch_sky_transition_plan` | `scripts/services/sky_profile_applier.gd`, `data/sky_profiles/*.tres` |
| [4-3](./4-3-launch-vfx.md) | Launch VFX / Result Overlay (`GPUParticles2D` + `VideoStreamPlayer`) | `rocket_launch_implementation_spec §9` | `scenes/launch/launch_vfx.tscn`, `scenes/transitions/milestone_video_overlay.tscn` |

### 5. Meta / Collection
| ID | 시스템 | 정본 문서 참조 | Godot 매핑 |
|---|---|---|---|
| [5-1](./5-1-discovery.md) | Discovery / Codex (도감 12 엔트리) | `celestial_codex_design_plan`, `celestial_codex_plan` | `scripts/services/discovery_service.gd`, `data/codex_config.tres` |
| [5-2](./5-2-badge.md) | Badge (19종, Steam/GPG/iOS Achievement 매핑) | `destination_config §7` | `scripts/services/badge_service.gd`, `data/badge_config.tres` |
| [5-3](./5-3-mission.md) | Mission (일일/주간) | `bm §9.2`, `post_landing_bm_plan §5` | `scripts/services/mission_service.gd`, `data/mission_config.tres` |
| [5-4](./5-4-leaderboard.md) | Best Records (로컬 베스트, V2 외부 리더보드) | `flow §1` | `scripts/services/best_records_service.gd` |

### 6. Meta Bonus (구 Social, 싱글 재설계)
| ID | 시스템 | 정본 문서 참조 | Godot 매핑 |
|---|---|---|---|
| [6-1](./6-1-social-actions.md) | Meta Bonus (Daily Login / Codex Progress / Playtime Title / 평점 모달) | `social_bm` | `scripts/services/meta_bonus_service.gd`, `data/meta_bonus_config.tres` |
| [6-2](./6-2-party-buff.md) | Season Collection (시즌 한정 코스메틱) | `social_bm §3.7`, `bm §6` | `scripts/services/season_service.gd`, `data/season_collection_config.tres` |

### 7. Monetization
| ID | 시스템 | 정본 문서 참조 | Godot 매핑 |
|---|---|---|---|
| [7-1](./7-1-gamepass.md) | 영구 IAP + Steam Standard/Deluxe (VIP / Auto Launch Pass / Guidance Module) | `bm §3.1, §7.1` | `scripts/services/iap_service.gd`, `data/iap_config.tres` |
| [7-2](./7-2-developer-product.md) | 소모 IAP + Steam Cosmetic DLC (Boost / Surge / Fuel / Shield / Purge / Credit Pack / Bundle) | `bm §3.2~3.4, §8` | `iap_service.gd`, `data/iap_config.tres`, `data/dlc_config.tres` |
| [7-3](./7-3-daily-planned.md) | Daily Reward + Daily Mission + Rewarded Ads (V1) | `bm §4, §9` | `scripts/services/daily_reward_service.gd`, `scripts/services/daily_mission_service.gd`, `scripts/services/ad_reward_service.gd` |
| [7-4](./7-4-subscription-planned.md) | Subscription Orbital Operations Pass + Battle Pass (V1) | `bm §5, §6` | `scripts/services/subscription_service.gd`, `scripts/services/battle_pass_service.gd` |

### 8. Shell / Platform
| ID | 시스템 | 정본 문서 참조 | Godot 매핑 |
|---|---|---|---|
| [8-1](./8-1-player-data.md) | SaveSystem (`user://savegame.json`) | `system_mapping_analysis §5` | `scripts/autoload/save_system.gd`, `scripts/autoload/game_state.gd` |
| [8-2](./8-2-network.md) | EventBus (시그널 버스, V2 클라우드 동기화 옵션) | `rocket_launch_implementation_spec §1` | `scripts/autoload/event_bus.gd` |
| [8-3](./8-3-di-container.md) | Godot Autoload (서비스 부팅 / 의존성) | — (Godot 표준) | `project.godot` `[autoload]` 섹션 |
| [8-4](./8-4-ui-shell.md) | UI Shell (`MainScreen` / `GlobalHUD` / `LaunchApp` / `PlayerStateService`) | `rocket_launch_implementation_spec §9.1`, `ui_design_guide` | `scenes/main/main_screen.tscn`, `scenes/ui/global_hud.tscn`, `scripts/services/player_state_service.gd` |
| [8-5](./8-5-telemetry.md) | TelemetryService (로컬 + 옵션 Steam User Stats / GPG / Firebase) | — (코드 베이스) | `scripts/services/telemetry_service.gd` |

---

## 의존성 흐름 요약

```
[8. Shell: SaveSystem / EventBus / Autoload / UI Shell / Telemetry] ← 모든 시스템의 기반
        ↓
[1. Launch Core: Session → Multi-Stage → Stress → AutoLaunch + Offline Progress]
        ↓ 성공/완료 시그널 (EventBus)
[2. Progression: Destination → Region → Program Lv. → LaunchTech / Facility]
        ↓ 보상 지급
[3. Economy: XP / Credit / TechLevel 흐름]
        ↓
[4. Cinematic] 2D 연출 + [5. Meta: Discovery / Badge / Mission / Best Records] 기록 축
        ↓
[6. Meta Bonus] 일일 로그인 / 도감 보너스 / 시즌 컬렉션 + [7. Monetization] IAP / DLC / Subscription / Battle Pass
```

---

## 문서 구조 규약 (각 시스템 파일 포맷)

각 시스템 문서는 다음 섹션을 동일 순서로 유지한다:

1. **시스템 개요** — 한 줄 정의 + 책임 경계
2. **코어 로직** — 상태머신 / 공식 / 함수 플로우
3. **정적 데이터 (Config)** — `data/*.tres` (Godot Resource)
4. **플레이어 영속 데이터** — `user://savegame.json` 내 필드
5. **런타임 상태** — Autoload / 노드 메모리 변수
6. **시그널** — Godot Signal + `EventBus` 시그널 일람
7. **의존성** — 의존하는 서비스 / 의존받는 서비스
8. **관련 파일 맵** — 이 시스템에서 수정할 때 봐야 하는 Godot 파일

## 표기 규약

- **[코어]** 로직 — 행동 규칙, 상태 전이, 계산 공식
- **[Config]** — 정적 튜닝 값 (`Resource` 상속, `.tres`)
- **[SaveSystem]** — `user://savegame.json`에 영속 저장되는 플레이어 데이터
- **[Runtime]** — Autoload / 노드 메모리 변수
- **[Signal]** — Godot Signal (`EventBus.signal_name.emit(...)`)
