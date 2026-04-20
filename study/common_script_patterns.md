# Godot 4에서 자주 쓰는 스크립트 패턴

**질문**: 상태머신·오브젝트 풀링 같은 패턴이 Godot에서도 자주 쓰이는가? 다른 관용 패턴은 무엇이 있나?

**짧은 답**:
- **상태머신**: 매우 자주 쓰임. 3가지 구현(enum / node / statechart)이 경쟁. **대부분 enum이면 충분**하고, 복잡해지면 node 또는 statechart로 승격.
- **오브젝트 풀링**: **유니티만큼 보편적이진 않음**. GDScript는 참조 카운트 기반이라 GC 스파이크가 없어 부담이 덜함. 수백 개 동시 스폰하는 게임(탄막·파티클·토스트)에만 선별 적용.
- **그 외 필수 패턴**: `signal`, `await`, Groups, Unique Names(`%`), Tween 체인, 타입 힌트, Callable — 이들은 **거의 모든 Godot 프로젝트가 사용**.

StarReach(증분 시뮬) 관점에서 각 패턴의 "실제로 필요한가" 판정도 함께 기록.

---

## 1. 상태머신(Finite State Machine)

### 1.1 세 가지 구현 방식

| 방식 | 코드량 | 시각화 | 재사용 | 권장 상황 |
|---|---|---|---|---|
| **enum + match** | 최소 | ❌ | ❌ | 상태 5개 이하, 단순 분기 |
| **노드 기반 FSM** | 중 | ✅ (씬 트리) | 일부 | 캐릭터 행동(Idle/Run/Jump) |
| **State Charts (플러그인)** | 중·많음 | ✅ (전용 UI) | ✅ | 상태 폭발(state explosion), 병렬·계층 상태 |

### 1.2 enum + match (70%의 경우 충분)

```gdscript
extends Node

enum State { MENU, PLAYING, PAUSED, PRESTIGE }
var state: State = State.MENU

func _process(delta: float) -> void:
    match state:
        State.MENU:
            pass
        State.PLAYING:
            _tick_economy(delta)
        State.PAUSED:
            pass
        State.PRESTIGE:
            _animate_prestige(delta)

func transition_to(next: State) -> void:
    _exit(state)
    state = next
    _enter(next)
```

**장점**: 파일 하나, 전역 검색 용이, AI가 편집하기 쉬움.
**단점**: 상태가 늘면 거대한 match 블록. 한 상태의 로직이 다른 씬과 얽히기 어려움.

**StarReach 적용**: ✅ GameState의 게임 플로우 상태(MENU/PLAYING/PRESTIGE_ANIM), UI 버튼 상태(NORMAL/DISABLED/LOCKED) 정도면 enum 충분.

### 1.3 노드 기반 FSM

각 상태가 Node 하나. 루트에 `StateMachine` 노드를 두고, 자식으로 `IdleState`, `RunState` 등을 배치. 전환은 스크립트 프로퍼티 교체.

```
Player
└── StateMachine (state_machine.gd)
    ├── Idle       (idle_state.gd)
    ├── Run        (run_state.gd)
    └── Jump       (jump_state.gd)
```

```gdscript
# 공통 상태 베이스
class_name State
extends Node

func enter() -> void: pass
func exit() -> void: pass
func update(_delta: float) -> void: pass
func handle_input(_event: InputEvent) -> void: pass
```

**장점**: 상태 코드 분리, 씬에서 시각 확인, `@export`로 전환 파라미터 튜닝.
**단점**: 파일 여러 개, 공유 상태 중복 가능성. **헤드리스-퍼스트 방침과 약간 충돌** — 각 상태 노드를 `.tscn`에 붙이는 게 유리한데 텍스트 편집 부담 증가.

**StarReach 적용**: ❌ 증분 시뮬은 캐릭터 상태 행동이 없어 불필요. 다만 **튜토리얼 흐름**처럼 단계가 많은 경우 고려.

### 1.4 State Charts (UML statechart 기반 플러그인)

`derkork/godot-statecharts` 커뮤니티 플러그인. **계층 상태**, **병렬 상태**, **히스토리 상태**, **가드 조건** 지원. 선언적 `.tscn` 에디터.

```
StateChart (node)
├── Menu
├── Playing
│   ├── Active        (compound state)
│   │   ├── Running
│   │   └── Paused
│   └── Prestige
└── GameOver
```

**장점**: 복잡한 상태 표현, 시각적 디버깅, UI 전환·게임 루프·튜토리얼을 **하나의 차트**로 통합.
**단점**: 학습 곡선, 플러그인 의존, 단순 게임에 과한 도구.

**StarReach 적용**: ⏳ 초기엔 불필요. 프레스티지·이벤트·튜토리얼이 동시에 활성화되는 복잡도가 생기면 그때 도입 검토.

---

## 2. 오브젝트 풀링

### 2.1 Godot에서는 왜 덜 쓰이나

유니티(C#)에서 풀링이 필수적인 이유는 **GC 스파이크** 때문. Godot의 GDScript는 **참조 카운트** 기반이라 GC pause가 없다. 또한 `Node.new()`와 `PackedScene.instantiate()`는 상대적으로 저렴.

**그래서 Godot에서는**:
- 1초에 수천 개 스폰하는 경우(탄막·파티클 효과 셸·대량 픽업)만 풀링.
- 일반적인 게임(수십 개 동시)에는 그냥 `instantiate()` + `queue_free()`가 관행.

### 2.2 그래도 풀링이 이득인 경우

1. **오디오 플레이어** (이미 `SfxDirector`에서 구현) — 재생은 짧고 빈번, 초기화 비용 큼.
2. **파티클 이펙트 노드** — GPUParticles2D는 셰이더 컴파일 비용이 있어 매번 스폰 시 프레임 드롭 가능.
3. **UI 토스트/데미지 넘버** — 초당 10개 이상 스폰되면 `queue_free` 경합.
4. **MultiMeshInstance2D로 전환** — 수천 개라면 풀링보다 MultiMesh가 더 효율적.

### 2.3 기본 풀 구현

```gdscript
# res://shared/utils/node_pool.gd
class_name NodePool
extends Node

@export var scene: PackedScene
@export var prefill: int = 16

var _free: Array[Node] = []
var _active: Array[Node] = []

func _ready() -> void:
    for i in prefill:
        var n: Node = scene.instantiate()
        n.process_mode = Node.PROCESS_MODE_DISABLED
        _free.append(n)
        add_child(n)

func acquire() -> Node:
    var n: Node
    if _free.is_empty():
        n = scene.instantiate()
        add_child(n)
    else:
        n = _free.pop_back()
    n.process_mode = Node.PROCESS_MODE_INHERIT
    if n is CanvasItem:
        n.visible = true
    _active.append(n)
    return n

func release(n: Node) -> void:
    if not _active.has(n): return
    _active.erase(n)
    n.process_mode = Node.PROCESS_MODE_DISABLED
    if n is CanvasItem:
        n.visible = false
    _free.append(n)
```

**함정**:
- `visible = false`만 해도 `_process`는 돌아감 → `process_mode = DISABLED` 병행.
- `Node2D`는 부모에서 transform을 상속하므로 풀 노드를 재배치할 때 주의.
- 파티클 노드 풀링 시 `restart()`로 재시작.

### 2.4 StarReach 적용 지점

이전 설계(`resource_architecture_design.md`)의 **Director들이 이미 풀링을 내장**하도록 설계됨:

- `SfxDirector`: `AudioStreamPlayer` 풀 (이미 구현).
- `FxDirector`: `GPUParticles2D`/`CPUParticles2D`를 `one_shot` + `queue_free` 방식으로 스폰. **한 번에 여러 개 스폰이 많아지면 풀링 전환** 고려.
- 미래 확장: **획득 숫자 플로팅 라벨**(+123 coins!)이 자주 뜨면 `ToastPool` 추가.

**판정**: ✅ 오디오(필수), ⏳ 파티클·토스트(필요 시점에 도입).

---

## 3. 시그널 + `await` — Godot 4의 핵심 패턴

### 3.1 시그널 연결

```gdscript
# 코드 연결(권장)
btn.pressed.connect(_on_pressed)

# 인자 전달
btn.pressed.connect(_on_pressed.bind(&"buy", 42))

# 일회성 연결
sig.connect(cb, CONNECT_ONE_SHOT)

# 디퍼드(다음 프레임에 콜백)
sig.connect(cb, CONNECT_DEFERRED)
```

### 3.2 `await` — 콜백을 없앤다

Godot 4에서 가장 자주 쓰는 패턴. **복잡한 UI 플로우와 애니메이션 시퀀스**에 특히 강력.

```gdscript
func _on_prestige_pressed() -> void:
    $ConfirmDialog.show()
    var confirmed: bool = await $ConfirmDialog.closed
    if not confirmed: return

    var tw := create_tween()
    tw.tween_property(self, "modulate:a", 0.0, 0.5)
    await tw.finished

    GameState.perform_prestige()
    EventBus.prestige_reset.emit()

    await get_tree().create_timer(1.0).timeout
    SceneLoader.load_and_switch("res://features/main_menu/main_menu.tscn")
```

→ 콜백 체인 없이 위에서 아래로 읽힘. **Async·Promise·Coroutine**의 GDScript 버전.

**주의**:
- Tween의 `duration == 0`이면 `finished`가 즉시 발화하지 않아 `await`가 영구 대기. 사전 조건 체크 필수.
- `await` 중 씬이 `queue_free`되면 에러 — `is_instance_valid()` 체크 또는 `CONNECT_ONE_SHOT`.

### 3.3 `signal.emit()` — 단방향 방송

```gdscript
# EventBus.gd
signal currency_changed(id: StringName, amount: float)

# GameState.gd — 발신자
EventBus.currency_changed.emit(&"coin", new_balance)

# CurrencyLabel.gd — 수신자
func _ready() -> void:
    EventBus.currency_changed.connect(_on_changed)

func _on_changed(id: StringName, amount: float) -> void:
    if id != my_id: return
    text = NumberFormat.short(amount)
```

---

## 4. Groups — 이름 태그로 노드 찾기

```gdscript
# 등록
enemy.add_to_group(&"enemies")
collectible.add_to_group(&"collectibles")

# 일괄 조작
get_tree().call_group(&"enemies", "take_damage", 10)
for e in get_tree().get_nodes_in_group(&"enemies"):
    e.freeze()
```

**언제 유용**: "같은 타입의 노드 전부에게 메시지". 노드 참조를 일일이 유지하지 않고도 동작.

**StarReach 적용**: ⏳ 드물게. 예: 프레스티지 시 `get_tree().call_group(&"resets_on_prestige", "reset")`.

---

## 5. Unique Names (`%`) — 깊은 경로 탈출

씬 트리가 깊어질 때 `$VBox/HBox/Container/Button` 대신 **Unique Name**으로 접근.

```gdscript
# .tscn에서 노드에 "Unique in owner" 플래그를 준 뒤
@onready var buy_btn: Button = %BuyButton   # 경로 대신 이름
@onready var cost_label: Label = %CostLabel
```

- 씬 내부 구조가 바뀌어도 참조가 안 깨짐.
- 같은 씬 내에서 유일해야 함.
- **AI가 `.tscn`을 수정하기 쉽게** 해줌 — 경로 문자열 변경 줄어듦.

**StarReach 적용**: ✅ `features/*` UI에 적극 활용 권장.

**헤드리스 팁**: `.tscn`에서 노드에 `unique_name_in_owner = true` 속성 추가하면 됨. scene-surgeon이 처리.

---

## 6. Tween — 현대 Godot의 애니메이션 기본값

AnimationPlayer가 없이도 **코드만으로** 부드러운 애니메이션.

```gdscript
# 기본
var tw := create_tween()
tw.tween_property(label, "modulate:a", 0.0, 0.5)

# 연쇄 (순차)
var tw := create_tween()
tw.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
tw.tween_callback(_on_bounce_done)

# 병렬
var tw := create_tween().set_parallel(true)
tw.tween_property(self, "position", target, 0.3)
tw.tween_property(self, "modulate:a", 1.0, 0.3)

# 루프
var tw := create_tween().set_loops()
tw.tween_property(ring, "rotation", TAU, 2.0)

# 이징
tw.tween_property(x, "scale", Vector2.ONE, 0.3)\
  .set_trans(Tween.TRANS_ELASTIC)\
  .set_ease(Tween.EASE_OUT)
```

**헤드리스-퍼스트 친화**: AnimationPlayer는 에디터 타임라인이 필요하지만, Tween은 **순수 코드** → AI가 완결 가능.

**StarReach 적용**: ✅ UI 애니메이션 전부를 Tween으로. 복잡한 캐릭터 애니메이션만 AnimationPlayer.

---

## 7. `@export` + Custom Resource = Strategy 패턴

**행동을 바꾸고 싶을 때 서브클래스를 만들지 말고, 데이터를 바꾼다**.

```gdscript
# 비용 곡선 전략을 Resource로 분리
class_name CostCurve
extends Resource

func cost_at(level: int) -> float:
    return 0.0

# 구체 구현
class_name ExponentialCost
extends CostCurve

@export var base: float = 10.0
@export var growth: float = 1.15

func cost_at(level: int) -> float:
    return base * pow(growth, level)

# 사용처
class_name GeneratorData
extends Resource

@export var cost_curve: CostCurve   # 다형성 — 여러 구현 교체 가능
```

`.tres`에서 `cost_curve`에 `ExponentialCost` 인스턴스, `LinearCost` 인스턴스, `PolynomialCost` 인스턴스를 갈아 끼울 수 있음. **클래스 계층 없이 런타임 행동 교체**.

**StarReach 적용**: ✅ 업그레이드 효과, 비용 곡선, 재화 증식 공식 등.

---

## 8. Callable — 일급 함수 (Command 패턴)

```gdscript
# 함수를 값으로 저장
var actions: Dictionary[StringName, Callable] = {
    &"buy_1": func(): GameState.buy(&"gen_01"),
    &"buy_max": func(): GameState.buy_max(&"gen_01"),
    &"prestige": GameState.perform_prestige,
}

# 실행
actions[&"buy_max"].call()

# 시그널 연결에도
btn.pressed.connect(actions[&"buy_1"])
```

**Undo/Redo**, **커맨드 큐**, **버튼 설정 데이터화**에 유용.

**StarReach 적용**: ⏳ 업적·이벤트 트리거를 데이터로 정의할 때.

---

## 9. 타입 힌트 (GDScript 2)

루트 `CLAUDE.md`에 이미 **필수 규칙**으로 명시됨. 여기서는 자주 놓치는 형태만 정리.

```gdscript
# 로컬 변수도 타입 힌트
var items: Array[ItemData] = []

# 람다도
var total: int = items.reduce(func(acc: int, i: ItemData) -> int: return acc + i.value, 0)

# Dictionary 4.4+ 타입드
var by_id: Dictionary[StringName, ItemData] = {}

# 시그널 인자
signal currency_changed(id: StringName, amount: float)

# 반환 void 명시
func apply() -> void: ...
```

**정적 타입 = 빠른 실행 + 에러 조기 검출 + AI 친화**. GDScript 2는 타입 있는 코드가 없는 코드보다 실측 2배 이상 빠름.

---

## 10. Error/Warning 처리 관용

```gdscript
# 경고 (디버그 콘솔에 노출)
push_warning("Missing SFX: %s" % id)

# 에러
push_error("Save failed: %s" % err)

# 가정
assert(node != null, "node was null")   # 릴리스에서 비활성

# Error 열거형
var e: Error = FileAccess.open("res://x", FileAccess.READ).get_error()
if e != OK:
    push_error("Open failed: %d" % e)
```

**관례**:
- 사용자 입력·파일 I/O는 **경계**에서 검사.
- 내부 로직은 `assert`.
- `print()`는 임시 디버깅용만.

---

## 11. 패턴 사용 빈도 (StarReach 관점)

| 패턴 | Godot 일반 | StarReach 필수? |
|---|---|---|
| signal + await | ⭐⭐⭐⭐⭐ | ✅ |
| @export + Custom Resource | ⭐⭐⭐⭐⭐ | ✅ |
| Autoload | ⭐⭐⭐⭐⭐ | ✅ |
| Tween | ⭐⭐⭐⭐⭐ | ✅ |
| Unique Names (%) | ⭐⭐⭐⭐ | ✅ |
| 타입 힌트 | ⭐⭐⭐⭐⭐ | ✅ (CLAUDE.md 필수) |
| enum FSM | ⭐⭐⭐⭐ | ✅ (GameState 상태) |
| 노드 FSM | ⭐⭐⭐ | ⏳ (필요 시) |
| State Charts | ⭐⭐ | ❌ 초기엔 불필요 |
| Callable | ⭐⭐⭐ | ⏳ |
| Groups | ⭐⭐⭐ | ⏳ |
| Object Pool (수동) | ⭐⭐ | 부분 — Director들에 내장 |
| MultiMesh (대량) | ⭐⭐ | ❌ |
| @tool 헤드리스 | ⭐⭐ | ✅ (빌드 스크립트) |

---

## 12. 금기 패턴 / 흔한 실수

### 12.1 `get_node("../../..")` 체인

부모의 부모의 부모를 찾지 말 것. **EventBus, Groups, Unique Names, @export**로 해결.

### 12.2 `_process`에서 `get_node()` 매 프레임

```gdscript
# ❌
func _process(_d):
    $Player/Weapon/Muzzle.fire()

# ✅
@onready var muzzle: Node2D = %Muzzle
func _process(_d):
    muzzle.fire()
```

### 12.3 `signal`을 메서드처럼 남용

EventBus가 수십 개 시그널로 비대해지면 **결합 추적 불가**. 전역 시그널은 정말 전역인 것만.

### 12.4 상태를 두 군데에 두기

`GameState.coin = 100`과 UI 라벨 `text = "100"`을 각각 업데이트하지 말 것. **GameState가 진실**, UI는 **signal 구독으로 반영만**.

### 12.5 `yield` 코드 남음

Godot 3의 `yield(obj, "signal")`은 Godot 4에서 `await obj.signal`로 바뀜. 튜토리얼이 옛날 것이면 주의.

### 12.6 Tween 중첩 생성

같은 노드에 Tween이 여러 개 만들어지면 충돌. `kill()` 후 재생성 또는 `set_trans/set_ease` 통합.

---

## 13. 결론 — StarReach에 지금 도입할 것 vs 나중에

**지금**:
- signal + await
- Autoload (GameState, EventBus, Directors)
- @export + Custom Resource (Scriptable Object식 데이터 주도)
- Tween
- Unique Names (`%`)
- 타입 힌트
- enum FSM (GameState 게임 플로우)
- 풀링(오디오/파티클 — Director 내장)

**나중에(트리거 있을 때)**:
- 노드 FSM — 캐릭터 상태 행동이 생기면
- State Charts — 튜토리얼·이벤트 병렬 상태가 많아지면
- Callable 커맨드 테이블 — 업적·데일리 미션
- Groups — 프레스티지 리셋 대상 일괄 관리

**이번 프로젝트에서는 불필요**:
- MultiMesh·대량 탄막 풀링 (장르 불일치)
- 복잡한 AI 행동 트리

---

## 14. 참고 자료

- [Design patterns in Godot — GDQuest](https://www.gdquest.com/tutorial/godot/design-patterns/intro-to-design-patterns/)
- [Make a Finite State Machine in Godot 4 — GDQuest](https://www.gdquest.com/tutorial/godot/design-patterns/finite-state-machine/)
- [Starter state machines in Godot 4 — The Shaggy Dev](https://shaggydev.com/2023/10/08/godot-4-state-machines/)
- [Godot State Charts (derkork)](https://github.com/derkork/godot-statecharts)
- [Awaiting multiple signals in Godot 4 — The Shaggy Dev](https://shaggydev.com/2025/06/12/godot-awaiting-signals/)
- [Best practices with Godot signals — GDQuest](https://www.gdquest.com/tutorial/godot/best-practices/signals/)
- [Tween class reference — Godot Docs](https://docs.godotengine.org/en/stable/classes/class_tween.html)
- [Object Pool 논의 — Godot Forum](https://godotforums.org/d/29490-object-pool-arrays)
- [qurobullet (대량 풀링 레퍼런스)](https://github.com/quinnvoker/qurobullet)
