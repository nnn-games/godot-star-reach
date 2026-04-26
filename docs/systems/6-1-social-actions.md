# 6-1. Meta Bonus Service — 일일 로그인 / 평점 / 플레이타임 / 도감 칭호

> 카테고리: Meta Retention
> 구현: `scripts/services/meta_bonus_service.gd`

## 1. 시스템 개요

싱글 오프라인 게임의 **메타 보상 통합 서비스**. 멀티/소셜 메커니즘 없이 동일한 리텐션 효과를 다음 4개 축으로 대체합니다.

| 축 | 트리거 | 대표 보상 |
|---|---|---|
| **Daily Login** | 매일 첫 진입(UTC 자정 기준) | 1~7일 스트릭 → Day 7 칭호 `Weekly Explorer` |
| **Rating Modal** | 누적 플레이타임 + 진척 임계 | 평점 페이지 이동 (Steam Wishlist / Google Play / iOS App Store) |
| **Playtime Titles** | 누적 플레이타임 5단계 | Cadet → Stellar Architect 칭호 + Credit |
| **Codex Progress** | 도감 25/50/75/100% 임계 | 칭호 + Credit (`RegionMasteryService`로 적용) |

**책임 경계**
- 일일 로그인 스트릭 카운터 (UTC 자정 기준 리셋, 24h 초과 시 끊김).
- 누적 플레이타임 누산 + 단계 임계 도달 시 1회성 보상 발급.
- 도감 진척률 임계 도달 감지 + 보상 발급.
- 플랫폼별 평점 모달 노출 시점/쿨다운 관리.

**책임 아닌 것**
- 칭호 표시 UI (→ `TitleService` / 클라이언트 `TitleBadge`).
- Credit 잔액 갱신 (→ `CurrencyService.add_credit`).
- 도감 진척률 자체 계산 (→ `CodexService.get_progress_ratio`).
- IAP 결제 모달 (→ `IAPService`, 단 평점 모달은 본 서비스가 호출).

## 2. 코어 로직

### 2.1 Daily Login Streak (`claim_daily_login`)

```gdscript
func claim_daily_login() -> DailyClaimResult:
	var today_utc: int = _get_utc_day_index()  # Unix / 86400, UTC
	var last_day: int = save_data.daily_login.last_day_index
	if today_utc == last_day:
		return DailyClaimResult.new(false, "already_claimed_today")

	# 연속 여부: 정확히 어제만 streak 유지, 그 외는 1로 리셋
	if today_utc == last_day + 1:
		save_data.daily_login.streak = mini(save_data.daily_login.streak + 1, 7)
	else:
		save_data.daily_login.streak = 1

	save_data.daily_login.last_day_index = today_utc
	var reward: DailyReward = config.daily_login_rewards[save_data.daily_login.streak - 1]
	_apply_reward(reward)
	EventBus.daily_login_claimed.emit(save_data.daily_login.streak, reward)
	return DailyClaimResult.new(true, "ok", reward)
```

- Day 1~6: Credit 소량 (스트릭 가속용).
- Day 7: 칭호 `Weekly Explorer` + Credit. 다음 날 1로 자연 순환 (7일을 넘기면 다시 1).

### 2.2 Playtime Titles (`tick_playtime`)

```gdscript
func tick_playtime(delta_seconds: float) -> void:
	save_data.total_playtime_sec += delta_seconds
	# 미수령 단계 중 가장 낮은 것부터 차례로 해제
	for tier in config.playtime_titles:
		if save_data.total_playtime_sec >= tier.required_seconds \
		and not save_data.unlocked_playtime_titles.has(tier.id):
			save_data.unlocked_playtime_titles.append(tier.id)
			_grant_title(tier.title_id)
			CurrencyService.add_credit(tier.credit_reward)
			EventBus.playtime_title_unlocked.emit(tier)
```

5단계: `Cadet (10h) / Engineer (50h) / Mission Director (100h) / Veteran Operator (500h) / Stellar Architect (1000h)`.

### 2.3 Codex Progress Bonus (`on_codex_progress_changed`)

```gdscript
func on_codex_progress_changed(progress_ratio: float) -> void:
	for bonus in config.codex_progress_bonuses:
		if progress_ratio >= bonus.threshold \
		and not save_data.claimed_codex_bonuses.has(bonus.threshold):
			save_data.claimed_codex_bonuses.append(bonus.threshold)
			_grant_title(bonus.title_id)
			CurrencyService.add_credit(bonus.credit_reward)
			EventBus.codex_bonus_unlocked.emit(bonus)
```

임계: `0.25 / 0.50 / 0.75 / 1.00`. 100% 임계 시 시그니처 칭호 (예: `Galactic Cartographer`).

### 2.4 Rating Modal Trigger (`evaluate_rating_modal`)

```gdscript
func evaluate_rating_modal() -> void:
	if save_data.rating_modal_state == RatingState.RATED \
	or save_data.rating_modal_state == RatingState.DECLINED_PERMANENT:
		return
	var now: int = Time.get_unix_time_from_system()
	if now - save_data.rating_modal_last_shown_at < RATING_COOLDOWN_SEC:
		return  # 14일 쿨다운

	for trig in config.rating_modal_triggers:
		if _meets_trigger(trig):
			save_data.rating_modal_last_shown_at = now
			IAPService.open_rating_page(_get_platform_target())
			EventBus.rating_modal_shown.emit(trig.id)
			return
```

- 트리거 예: `playtime>=50h AND highest_tier>=3`, `playtime>=100h AND codex>=0.5`.
- 플랫폼 분기는 `IAPService.open_rating_page`가 처리 (Steam Wishlist URL / `OS.shell_open`로 스토어 페이지 호출).

### 2.5 일일 자정 리셋 검사 (`_check_daily_rollover`)

```gdscript
func _process(delta: float) -> void:
	tick_playtime(delta)
	if Time.get_unix_time_from_system() - _last_rollover_check > 60:
		_last_rollover_check = Time.get_unix_time_from_system()
		var today_utc: int = _get_utc_day_index()
		# 24h 초과 미접속 → 다음 claim 시 자동 streak 1로 떨어짐
		if today_utc > save_data.daily_login.last_day_index + 1 \
		and save_data.daily_login.streak > 0:
			EventBus.daily_login_streak_broken.emit(save_data.daily_login.streak)
```

## 3. 정적 데이터 (Config)

### `data/meta_bonus_config.tres` (`MetaBonusConfig`)

```gdscript
class_name MetaBonusConfig extends Resource

@export var daily_login_rewards: Array[DailyReward] = []          # length = 7
@export var playtime_titles: Array[PlaytimeTitle] = []            # length = 5
@export var codex_progress_bonuses: Array[CodexBonus] = []        # length = 4
@export var rating_modal_triggers: Array[RatingTrigger] = []
@export var rating_cooldown_sec: int = 1209600                    # 14d


class_name DailyReward extends Resource
@export var day_index: int = 1                                    # 1~7
@export var credit_reward: int = 0
@export var title_id: StringName = &""                            # Day 7만 사용


class_name PlaytimeTitle extends Resource
@export var id: StringName = &""                                  # "tier_cadet"
@export var title_id: StringName = &""                            # "Cadet"
@export var required_seconds: int = 36000
@export var credit_reward: int = 0


class_name CodexBonus extends Resource
@export var threshold: float = 0.25
@export var title_id: StringName = &""
@export var credit_reward: int = 0


class_name RatingTrigger extends Resource
@export var id: StringName = &""
@export var min_playtime_sec: int = 0
@export var min_highest_tier: int = 0
@export var min_codex_ratio: float = 0.0
```

### 기본값 예시

```
daily_login_rewards:
  Day 1: 50 Credit
  Day 2: 100 Credit
  Day 3: 200 Credit
  Day 4: 300 Credit
  Day 5: 500 Credit
  Day 6: 750 Credit
  Day 7: 1500 Credit + Title "Weekly Explorer"

playtime_titles:
  Cadet               10h    +1,000 Credit
  Engineer            50h    +5,000 Credit
  Mission Director   100h   +15,000 Credit
  Veteran Operator   500h   +75,000 Credit
  Stellar Architect 1000h  +200,000 Credit

codex_progress_bonuses:
  25%  Title "Stellar Apprentice"  +2,000 Credit
  50%  Title "Cosmic Surveyor"     +6,000 Credit
  75%  Title "Deep Space Adept"   +20,000 Credit
 100%  Title "Galactic Cartographer" +60,000 Credit

rating_modal_triggers:
  trig_a: playtime>=50h AND highest_tier>=3
  trig_b: playtime>=100h AND codex_ratio>=0.5
```

## 4. 플레이어 영속 데이터 — `user://savegame.json`

```gdscript
"meta_bonus": {
	"version": 1,
	"daily_login": {
		"last_day_index": 0,           # UTC days since epoch
		"streak": 0                     # 0~7
	},
	"total_playtime_sec": 0.0,
	"unlocked_playtime_titles": [],     # ["tier_cadet", ...]
	"claimed_codex_bonuses": [],        # [0.25, 0.5, ...]
	"rating_modal_state": "pending",   # "pending" | "rated" | "declined_permanent"
	"rating_modal_last_shown_at": 0    # Unix
}
```

오프라인 진행 처리: 로드 시 `tick_playtime`은 호출하지 않습니다 — 플레이타임은 활성 세션 시간만 누적 (오프라인 자동 진행은 `OfflineProgressService` 책임).

## 5. 런타임 상태

| 필드 | 용도 |
|---|---|
| `_last_rollover_check: int` | 자정 검사 throttle (60초 간격) |
| `_session_start_unix: int` | 세션 시작 시각, 통계용 |
| `_pending_codex_threshold: float` | 마지막으로 평가한 도감 진척률 (재평가 회피) |

## 6. 시그널 (EventBus)

```gdscript
# scripts/autoload/event_bus.gd
signal daily_login_claimed(streak: int, reward: DailyReward)
signal daily_login_streak_broken(prev_streak: int)
signal playtime_title_unlocked(tier: PlaytimeTitle)
signal codex_bonus_unlocked(bonus: CodexBonus)
signal rating_modal_shown(trigger_id: StringName)
```

UI는 이 시그널만 구독합니다. `MetaBonusService` 필드 직접 읽기 금지.

## 7. 의존성

**의존**:
- `SaveSystem` — `meta_bonus` 슬라이스 read/write.
- `CurrencyService.add_credit` — Credit 보상 적용.
- `TitleService.grant_title` — 칭호 영구 부여.
- `CodexService.get_progress_ratio` — Codex 진척 콜백 입력원.
- `IAPService.open_rating_page` — 플랫폼별 평점 페이지 호출.
- `Time.get_unix_time_from_system` — 자정/쿨다운 계산.

**의존받음**:
- `RegionMasteryService` — Codex 임계 도달 시 `on_codex_progress_changed` 호출.
- `MainScene._process` — `tick_playtime` 누산.
- 클라이언트 `DailyLoginPanel`, `PlaytimeTitlePanel`, `CodexProgressPanel`.

## 8. 관련 파일 맵

| 파일 | 역할 |
|---|---|
| `scripts/services/meta_bonus_service.gd` | 본 서비스 (오토로드) |
| `scripts/resources/meta_bonus_config.gd` | `MetaBonusConfig` + 하위 Resource 정의 |
| `data/meta_bonus_config.tres` | 밸런싱 데이터 |
| `scripts/autoload/event_bus.gd` | 본 카테고리 시그널 5종 |
| `scripts/services/save_system.gd` | `meta_bonus` 슬라이스 직렬화 |
| `scripts/services/iap_service.gd` | `open_rating_page` 진입점 |
| `scenes/ui/daily_login_panel.tscn` | 7일 스트릭 UI |
| `scenes/ui/playtime_title_panel.tscn` | 단계 진척 UI |
| `scenes/ui/codex_progress_panel.tscn` | 도감 임계 보상 UI |
