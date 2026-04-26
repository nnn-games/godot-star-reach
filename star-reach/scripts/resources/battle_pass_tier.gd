class_name BattlePassTier
extends Resource

## Single Battle Pass tier definition. `free_reward` and `premium_reward` use
## the same grants schema as IAPProduct.grants — keys: credit, tech_level,
## boosts {id: duration_sec}, shields {tier: count}.

@export var tier: int = 1
@export var xp_required: int = 0
@export var free_reward: Dictionary = {}
@export var premium_reward: Dictionary = {}
