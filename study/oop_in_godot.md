# Godot에서의 OOP — 얼마만큼 쓰고, 어떻게 다른가

**질문**: Godot 개발 시 OOP 도입이 일반적인가?

**짧은 답**:
- **YES**: Godot 전체가 OOP 기반. 모든 Node는 `Object → Node → Control/CanvasItem/...`의 클래스 계층이고, GDScript는 단일 상속 + `class_name`으로 정통 OOP를 지원.
- **BUT**: Java/C#처럼 **깊은 상속 트리를 만드는 건 Godot에서 안티패턴**. 엔진 철학 자체가 "**composition over inheritance**"를 공식 문서에 명시.
- 실전: 대부분의 클래스는 **내장 타입에서 1~2단계만 파생**. 나머지는 **씬 구성 + Resource 주입**으로 해결.

---

## 1. Godot의 OOP — 있는 것

| 기능 | GDScript 키워드 | 상태 |
|---|---|---|
| 단일 상속 | `extends Parent` | ✅ 전면 |
| 전역 클래스 등록 | `class_name Foo` | ✅ 에디터에 타입 노출 |
| 다형성 | 메서드 재정의 + `super.method()` | ✅ |
| 캡슐화(약함) | `_` 접두 convention | ⚠️ 강제력 없음(듀타이핑) |
| 타입 체크 | 정적 타입 힌트 + `is`, `as` | ✅ |
| 추상 클래스/메서드 | `@abstract` | ✅ Godot 4.5+ (이전 버전은 `assert`로 우회) |
| 내부 클래스(inner class) | `class Foo: ... end` | ✅ (거의 안 씀) |
| 정적 메서드/변수 | `static func`, `static var` | ✅ |
| 연산자 오버로드 | ❌ 없음 | — |

### 1.1 `class_name` — "이 클래스는 전역 타입이다"

```gdscript
class_name GeneratorDef
extends Resource

@export var id: StringName
@export var base_cost: float = 10.0
```

- 프로젝트 어디서든 `var d: GeneratorDef = GeneratorDef.new()` 로 즉시 참조.
- 에디터에서 `@export var def: GeneratorDef` 하면 인스펙터에 타입이 자동 인식.
- **재사용하는 타입에만** `class_name`. 한 씬 스크립트에는 붙이지 않음(전역 네임스페이스 오염).

### 1.2 `@abstract` (Godot 4.5+)

```gdscript
@abstract
class_name CostCurve
extends Resource

@abstract func cost_at(level: int) -> float
```

- `CostCurve.new()` 호출은 에러.
- 서브클래스는 `cost_at()`을 **반드시** 구현.
- 이전 버전에서는 베이스에 `push_error() + return 0.0`를 넣는 수동 우회.

### 1.3 다형성 예제

```gdscript
class_name Animal
func speak() -> String: return "..."

class_name Dog
extends Animal
func speak() -> String: return "Woof!"

# 사용
var a: Animal = Dog.new()
print(a.speak())   # "Woof!"
```

Liskov·다형성 원리 그대로. Godot 특이사항은 없음.

---

## 2. Godot의 OOP — 없는 것 (또는 다른 방식으로 해결)

### 2.1 인터페이스 (`interface` 키워드 없음)

**대체**: **duck typing**. `has_method()`, `has_signal()`로 런타임 체크.

```gdscript
func process_interactable(obj: Object) -> void:
    if obj.has_method(&"interact"):
        obj.interact()
```

또는 **빈 베이스 클래스를 인터페이스처럼 사용**:

```gdscript
class_name Saveable
extends RefCounted
@abstract func to_dict() -> Dictionary
@abstract func from_dict(d: Dictionary) -> void
```

이 베이스를 상속한 모든 클래스는 "Saveable 계약"을 따름. 다중 상속 불가라 한 계층으로 제한됨.

### 2.2 제네릭 / 템플릿 없음

**대체**: `Variant` + 런타임 체크, 또는 **타입드 Array/Dictionary**.

```gdscript
var items: Array[ItemData] = []         # 타입드 Array
var by_id: Dictionary[StringName, ItemData] = {}
```

Godot 4.4+의 타입드 컬렉션이 제네릭 수요의 80%를 해결.

### 2.3 접근 제어 수정자 없음

`private`/`protected`/`public` 없음. **관례로 `_` 접두**.

```gdscript
var speed: float = 1.0       # 공개
var _internal_state: int = 0 # 비공개(관례)
```

LSP·linter는 `_`로 시작하는 식별자를 외부에서 참조하면 경고만 띄운다.

### 2.4 친구 클래스 / 패키지 프라이빗 없음

모듈(파일) 단위 접근 제어는 없음. **파일 하나 = 클래스 하나** 관례로 유지하고 내부 결합이 필요한 코드는 같은 파일에 둠.

---

## 3. 고전 OOP 패턴이 엔진에 "내장"되어 있다

이것이 **가장 중요한 포인트**. GoF 패턴 중 절반 이상이 Godot의 기본 기능으로 이미 제공됨 → 따로 구현하지 말 것.

| GoF 패턴 | Godot 내장 | 추가 구현 필요? |
|---|---|---|
| **Composite** | 씬 트리 자체 | ❌ 그냥 사용 |
| **Observer** | `signal` + `connect()` | ❌ |
| **Singleton** | Autoload | ❌ |
| **Prototype** | `PackedScene.instantiate()` | ❌ |
| **Factory** | `PackedScene.instantiate()` + `new()` | ❌ |
| **Flyweight** | `Resource` 참조 공유 | ❌ |
| **Strategy** | `@export var foo: StrategyBase` | 가벼운 `.tres` 정의만 |
| **State** | enum + match, 또는 state 노드 | 단순한 경우 직접 |
| **Command** | `Callable` 타입 | ❌ |
| **Decorator** | 자식 노드 추가 | ❌ |
| **Chain of Responsibility** | 입력 이벤트 전파 시스템 | ❌ |
| **Memento** | `Resource.duplicate(true)` | ❌ |
| **Template Method** | `_ready()`/`_process()` 가상 메서드 | 이미 형태임 |

→ Godot 개발에서 "디자인 패턴 책 보면서 GoF 패턴 구현"은 대부분 **중복 작업**.

---

## 4. 실전 권장 — "얕은 상속 + 깊은 구성"

### 4.1 상속 깊이 가이드라인

실제 상용 Godot 프로젝트의 계층 깊이:

```
Object → Node → Control → Button  (엔진 4단계)
                    └── MyButton    (프로젝트 1단계 추가)
                    └── ShopButton  (드문 경우에만 2단계)
```

**엔진 클래스 위로 1~2단계**면 충분. 3단계 이상이면 설계 재검토.

### 4.2 "상속 대신 구성"이 맞는 상황

❌ 상속으로 풀지 마라:
- `Generator` → `MinerGenerator` → `SpeedMinerGenerator`
- `Enemy` → `FlyingEnemy` → `FastFlyingEnemy`

✅ 구성으로 풀어라:
- `Generator` 하나 + `GeneratorDef(Resource)`에 타입/속도/능력을 데이터로
- `Enemy` 하나 + `MovementComponent` / `AttackComponent` 자식 노드

### 4.3 "상속이 맞는" 상황

✅ 얕은 상속은 좋다:
- `Resource` → `GeneratorDef` (Scriptable Object)
- `Control` → `GeneratorRow` (재사용 UI 위젯)
- `Node` → `EventBus` (Autoload 싱글턴)
- `@abstract Resource` → `ExponentialCost` / `LinearCost` (Strategy 구현체들)

**공통 특징**: 재정의할 메서드가 **1~3개**, 서브클래스가 **2~5개**, 계층 **1단 깊이**.

### 4.4 "Component 노드" 패턴

복잡한 엔티티는 자식 노드로 **기능 단위 분해**:

```
Player (CharacterBody2D)
├── MovementComponent  (Node)      # velocity/direction 처리
├── HealthComponent    (Node)      # HP, 피격, 사망 신호
├── InventoryComponent (Node)      # 아이템 보관
└── SpriteAnimator     (Node2D)    # 시각 표현
```

각 컴포넌트는 **독립적 테스트·재사용** 가능. Enemy도 같은 컴포넌트를 조합해 재활용.

StarReach 같은 증분 시뮬에는 이 패턴이 덜 중요 (월드 엔티티가 없어서). 대신 **UI 컴포넌트**에서 자주 사용: `%SafeAreaMargin`, `%CurrencyCounter` 등.

---

## 5. StarReach에 적용 — 생성기 모델링 사례

**잘못된 접근 (Java/C# 관성)**:
```gdscript
class_name Generator
extends Node
class_name MinerGenerator     extends Generator
class_name RefineryGenerator  extends Generator
class_name ReactorGenerator   extends Generator
# 생성기 30종 = 클래스 30개 ❌
```

**Godot 관용 접근**:
```gdscript
class_name GeneratorDef
extends Resource
@export var id: StringName
@export var display_name: String
@export var base_cost: float
@export var cost_curve: CostCurve       # Strategy 주입
@export var base_output: float
@export var output_curve: OutputCurve   # Strategy 주입
@export var icon: Texture2D

# 공용 Controller 하나
class_name GeneratorRow
extends Control
@export var def: GeneratorDef
func _ready() -> void:
    %Icon.texture = def.icon
    %Name.text = def.display_name
    ...
```

생성기 30종 = `.tres` 30개. **코드는 한 벌**. 새 생성기 추가 = 데이터 추가.

**이것이 Godot의 핵심 Flyweight + Strategy + Composition 조합**. OOP 언어의 깊은 계층을 데이터로 평탄화.

---

## 6. 흔한 실수 (OOP 배경 개발자가 자주 저지름)

### 6.1 매 기능마다 서브클래스 만들기
생성기 30종을 30 클래스로 만드는 것. 위에서 본 대로 데이터로 해결.

### 6.2 인터페이스를 흉내내려다 과설계
GDScript에 `interface`가 없다고 여러 abstract 클래스를 쌓지 말 것. **duck typing** + `has_method()`가 대부분 충분.

### 6.3 접근 제어에 집착
`private` 없다고 getter/setter로 다 감싸지 말 것. `_prefix` 관례로 충분. **setter가 꼭 필요할 때**만 `@property` 대신 `set(value): ...` 블록으로.

```gdscript
var score: int = 0:
    set(value):
        score = max(0, value)
        EventBus.score_changed.emit(score)
```

### 6.4 모든 걸 `Node`로
UI나 엔티티가 아닌 **순수 데이터**는 `Resource` 또는 `RefCounted`. 불필요하게 씬 트리에 올리지 말 것.

### 6.5 `new()` vs `instantiate()` 혼동
- `MyClass.new()` — GDScript 클래스 인스턴스 (Resource/RefCounted/Object 계열)
- `preload("x.tscn").instantiate()` — 씬(노드 트리) 복제
- Node 단일을 코드로 만들 때는 `Node.new()` + `add_child()`.

### 6.6 Autoload에 OOP 패턴 남발
Autoload는 싱글턴 한 켤레. **다형성·상속 필요한 서비스는 싱글턴으로 만들지 말 것**. 대신 `.tres` Strategy 주입.

---

## 7. 요약 — Godot 개발자의 OOP 사고방식

- **씬이 클래스 계층을 대체한다**: `.tscn`가 "인스턴스", 자식 노드가 "필드", 노드 스크립트가 "메서드".
- **데이터가 다형성을 대체한다**: 행동 차이는 Resource 교체로.
- **시그널이 의존을 대체한다**: 참조 체인 대신 이벤트 발신.
- **Autoload가 전역 상태를 대체한다**: DI 컨테이너·서비스 로케이터 불필요.
- **상속은 신중하게, 구성은 과감하게**.

StarReach에서 이 철학을 따르면 **클래스 20개 미만**으로 전체 게임이 완성될 가능성이 큼. 같은 규모를 Java/C#로 짜면 100개 넘기 쉬움 — 그 차이가 "Godot OOP 스타일".

---

## 8. 참고 자료

- [Godot's design philosophy — 공식 문서](https://docs.godotengine.org/en/stable/getting_started/introduction/godot_design_philosophy.html)
- [Composition in Godot 4 — gotut.net](https://www.gotut.net/composition-in-godot-4/)
- [Abstract classes in 4.5 — Godot Forum](https://forum.godotengine.org/t/abstract-classes-in-4-5/115216)
- [Add support for abstract classes (proposal #5641)](https://github.com/godotengine/godot-proposals/issues/5641)
- [OOP Design Patterns in GDScript — UhiyamaLab](https://uhiyama-lab.com/en/notes/godot/oop-design-patterns/)
- [Favoring Composition Over Inheritance (O'Reilly book chapter)](https://www.oreilly.com/library/view/game-development-patterns/9781835880289/B22405_04.xhtml)
