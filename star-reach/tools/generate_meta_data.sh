#!/bin/bash
# One-shot generator for Phase 4b meta-progression resources:
#   - data/codex/*.tres        12 entries (Discovery / Codex Lite B)
#   - data/badges/*.tres       19 badges  (11 region first + 8 win count)
#   - data/missions/*.tres     7 daily mission defs
# Run once after any data redesign:
#   bash tools/generate_meta_data.sh

set -e
DATA_DIR="$(dirname "$0")/../data"
mkdir -p "$DATA_DIR/codex" "$DATA_DIR/badges" "$DATA_DIR/missions"

# ---------- Codex entries ----------
write_codex() {
  local id=$1; local name=$2; local summary=$3; shift 3
  local destinations="$*"
  # Convert "D_001 D_002 D_003" → '"D_001", "D_002", "D_003"'
  local arr_items=""
  for d in $destinations; do
    if [ -n "$arr_items" ]; then arr_items="$arr_items, "; fi
    arr_items="${arr_items}\"${d}\""
  done
  local fname=$(echo "$id" | tr '[:upper:]' '[:lower:]')
  cat > "${DATA_DIR}/codex/${fname}.tres" <<EOF
[gd_resource type="Resource" script_class="CodexEntry" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/codex_entry.gd" id="1_codex"]

[resource]
script = ExtResource("1_codex")
id = "${id}"
display_name = "${name}"
summary = "${summary}"
destination_ids = Array[String]([${arr_items}])
EOF
}

write_codex REGION_EARTH_OVERVIEW "Earth Region" \
  "Earth's atmosphere and the orbits closest to home, from troposphere to geostationary." \
  D_001 D_002 D_003 D_004 D_005 D_006 D_007 D_008 D_009 D_010

write_codex BODY_MOON "Moon" \
  "Earth's natural satellite — landing sites, near-side seas, and the far side." \
  D_013 D_014 D_015 D_016

write_codex SYSTEM_EARTH_MOON "Earth-Moon System" \
  "Translunar transfers and the gravitationally interesting space between Earth and Moon." \
  D_011 D_012 D_017 D_018 D_019 D_020

write_codex BODY_MARS "Mars" \
  "The red planet, its moons, and the largest volcano in the solar system." \
  D_021 D_022 D_023 D_024 D_025 D_026

write_codex BODY_VENUS "Venus" \
  "Solar system's hottest planet — orbital insertion and the Maat Mons volcano." \
  D_027 D_028

write_codex BODY_MERCURY "Mercury" \
  "Innermost planet — Caloris Basin and the closest orbit to the Sun." \
  D_029 D_030

write_codex SYSTEM_ASTEROID_BELT "Asteroid Belt" \
  "Rubble-pile worlds and the dwarf planet Ceres between Mars and Jupiter." \
  D_031 D_032 D_033 D_034 D_035 D_036 D_037 D_038 D_039 D_040

write_codex BODY_JUPITER "Jupiter" \
  "Gas giant of the outer solar system — Great Red Spot, rings, and magnetosphere." \
  D_041 D_042 D_043 D_044

write_codex BODY_EUROPA "Europa" \
  "Ice-shelled Galilean moon hiding a global subsurface ocean." \
  D_047 D_048 D_049 D_050

write_codex BODY_SATURN "Saturn" \
  "Ringed giant — A through F rings and the hexagonal polar storm." \
  D_051 D_052 D_053 D_054

write_codex BODY_TITAN "Titan" \
  "Saturn's largest moon — methane seas under a thick orange atmosphere." \
  D_055 D_056 D_057 D_058 D_059 D_060

write_codex BODY_PLUTO "Pluto System" \
  "Pluto, Charon, and the small moons at the edge of the classical solar system." \
  D_071 D_072 D_073 D_074 D_075

# ---------- Badges ----------
write_badge_region_first() {
  local id=$1; local name=$2; local region=$3; local achievement=$4
  local fname=$(echo "$id" | tr '[:upper:]' '[:lower:]')
  cat > "${DATA_DIR}/badges/${fname}.tres" <<EOF
[gd_resource type="Resource" script_class="BadgeDef" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/badge_def.gd" id="1_badge"]

[resource]
script = ExtResource("1_badge")
id = "${id}"
display_name = "${name}"
badge_type = "region_first"
region_id = "${region}"
threshold = 0
achievement_id = "${achievement}"
EOF
}

write_badge_win_count() {
  local id=$1; local name=$2; local threshold=$3; local achievement=$4
  local fname=$(echo "$id" | tr '[:upper:]' '[:lower:]')
  cat > "${DATA_DIR}/badges/${fname}.tres" <<EOF
[gd_resource type="Resource" script_class="BadgeDef" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/badge_def.gd" id="1_badge"]

[resource]
script = ExtResource("1_badge")
id = "${id}"
display_name = "${name}"
badge_type = "win_count"
region_id = ""
threshold = ${threshold}
achievement_id = "${achievement}"
EOF
}

# 11 region first
write_badge_region_first BADGE_REGION_EARTH         "Atmospheric Pioneer"  REGION_EARTH         "ach_first_earth"
write_badge_region_first BADGE_REGION_LUNAR_NEO     "Lunar Explorer"       REGION_LUNAR_NEO     "ach_first_lunar"
write_badge_region_first BADGE_REGION_INNER_SOLAR   "Mars Pathfinder"      REGION_INNER_SOLAR   "ach_first_mars"
write_badge_region_first BADGE_REGION_ASTEROID_BELT "Belt Navigator"       REGION_ASTEROID_BELT "ach_first_belt"
write_badge_region_first BADGE_REGION_JOVIAN        "Jovian Voyager"       REGION_JOVIAN        "ach_first_jovian"
write_badge_region_first BADGE_REGION_SATURNIAN     "Ringmaster"           REGION_SATURNIAN     "ach_first_saturnian"
write_badge_region_first BADGE_REGION_ICE_GIANTS    "Cryosphere Explorer"  REGION_ICE_GIANTS    "ach_first_ice"
write_badge_region_first BADGE_REGION_PLUTO_KUIPER  "Outer Bound"          REGION_PLUTO_KUIPER  "ach_first_kuiper"
write_badge_region_first BADGE_REGION_INTERSTELLAR  "Interstellar Pilot"   REGION_INTERSTELLAR  "ach_first_interstellar"
write_badge_region_first BADGE_REGION_MILKY_WAY     "Galactic Cartographer" REGION_MILKY_WAY    "ach_first_milky"
write_badge_region_first BADGE_REGION_DEEP_SPACE    "Cosmic Frontier"      REGION_DEEP_SPACE    "ach_first_deep"

# 8 win count
write_badge_win_count    BADGE_WINS_5     "First Steps"        5    "ach_wins_5"
write_badge_win_count    BADGE_WINS_25    "Frequent Flyer"     25   "ach_wins_25"
write_badge_win_count    BADGE_WINS_50    "Veteran Pilot"      50   "ach_wins_50"
write_badge_win_count    BADGE_WINS_100   "Centurion"          100  "ach_wins_100"
write_badge_win_count    BADGE_WINS_250   "Mission Master"     250  "ach_wins_250"
write_badge_win_count    BADGE_WINS_500   "Elite Operator"     500  "ach_wins_500"
write_badge_win_count    BADGE_WINS_1000  "Stellar Architect"  1000 "ach_wins_1000"
write_badge_win_count    BADGE_WINS_2500  "Legendary Captain"  2500 "ach_wins_2500"

# ---------- Missions ----------
write_mission() {
  local id=$1; local name=$2; local cond=$3; local target=$4; local reward=$5
  local fname=$(echo "$id" | tr '[:upper:]' '[:lower:]')
  cat > "${DATA_DIR}/missions/${fname}.tres" <<EOF
[gd_resource type="Resource" script_class="MissionDef" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/mission_def.gd" id="1_mission"]

[resource]
script = ExtResource("1_mission")
id = "${id}"
display_name = "${name}"
condition_id = &"${cond}"
target = ${target}
reward_tech_level = ${reward}
EOF
}

write_mission DM_LAUNCH_20         "Launch 20 times today"        launches            20 10
write_mission DM_SUCCESS_3         "Clear 3 destinations today"   successes           3  15
write_mission DM_STAGE_5_STREAK    "5 stages in a row"            stage_streak        5  10
write_mission DM_FACILITY_UPGRADE_1 "Buy 1 facility upgrade"       facility_upgrade    1  10
write_mission DM_PLAY_10M          "Play for 10 minutes"          play_minutes        10 15
write_mission DM_AUTO_LAUNCH_5M    "Run auto-launch for 5 min"    auto_launch_minutes 5  10
write_mission DM_NEW_DESTINATION   "Discover a new destination"   new_destinations    1  20

echo "Generated:"
echo "  $(ls "$DATA_DIR/codex" | wc -l) codex entries"
echo "  $(ls "$DATA_DIR/badges" | wc -l) badges"
echo "  $(ls "$DATA_DIR/missions" | wc -l) missions"
