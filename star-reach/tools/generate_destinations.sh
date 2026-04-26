#!/bin/bash
# One-shot generator for destination resources D_016~D_100.
# D_001~D_015 are hand-authored; this fixes D_016~D_020 (was wrongly tier=3 Mars)
# and creates D_021~D_100. Run once after any data redesign:
#   bash tools/generate_destinations.sh
# Outputs go to data/destinations/d_NNN.tres

set -e
DEST_DIR="$(dirname "$0")/../data/destinations"
mkdir -p "$DEST_DIR"

write_tres() {
  local id=$1; local name=$2; local tier=$3; local region=$4
  local stages=$5; local rc=$6; local rt=$7; local req=$8
  local nn
  nn=$(printf "%03d" "$id")
  cat > "${DEST_DIR}/d_${nn}.tres" <<EOF
[gd_resource type="Resource" script_class="Destination" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/destination.gd" id="1_dest"]

[resource]
script = ExtResource("1_dest")
id = "D_${nn}"
display_name = "${name}"
tier = ${tier}
region_id = "${region}"
required_stages = ${stages}
reward_credit = ${rc}
reward_tech_level = ${rt}
required_tech_level = ${req}
EOF
}

# D_016~D_020: fix Lunar assignment (was wrongly Mars T3 in Phase 2 stub)
write_tres 16 "Far Side of the Moon"         2 "REGION_LUNAR_NEO"     6  42  19  130
write_tres 17 "Lagrange Point L1"             2 "REGION_LUNAR_NEO"     6  47  21  149
write_tres 18 "James Webb Space Telescope"    2 "REGION_LUNAR_NEO"     6  52  23  170
write_tres 19 "Asteroid 99942 Apophis"        2 "REGION_LUNAR_NEO"     6  57  25  193
write_tres 20 "Asteroid Bennu"                2 "REGION_LUNAR_NEO"     6  62  27  218

# D_021~D_030: Inner Solar (Mars/Venus/Mercury) T3
write_tres 21 "Mars Transfer Orbit"           3 "REGION_INNER_SOLAR"   7  70  30  245
write_tres 22 "Deimos"                        3 "REGION_INNER_SOLAR"   7  78  32  275
write_tres 23 "Phobos"                        3 "REGION_INNER_SOLAR"   7  86  34  307
write_tres 24 "Olympus Mons"                  3 "REGION_INNER_SOLAR"   7  94  36  341
write_tres 25 "Valles Marineris"              3 "REGION_INNER_SOLAR"   8 102  38  377
write_tres 26 "Martian Polar Ice Caps"        3 "REGION_INNER_SOLAR"   8 110  40  415
write_tres 27 "Venus Orbit"                   3 "REGION_INNER_SOLAR"   8 118  42  455
write_tres 28 "Maat Mons (Venus)"             3 "REGION_INNER_SOLAR"   8 126  44  497
write_tres 29 "Mercury Orbit"                 3 "REGION_INNER_SOLAR"   8 134  46  541
write_tres 30 "Caloris Basin"                 3 "REGION_INNER_SOLAR"   8 142  48  587

# D_031~D_040: Asteroid Belt T3
write_tres 31 "Inner Asteroid Belt"           3 "REGION_ASTEROID_BELT" 8 150  49  635
write_tres 32 "Asteroid Eros"                 3 "REGION_ASTEROID_BELT" 8 158  50  684
write_tres 33 "Asteroid Gaspra"               3 "REGION_ASTEROID_BELT" 8 166  50  734
write_tres 34 "Ida and Dactyl"                3 "REGION_ASTEROID_BELT" 8 174  50  784
write_tres 35 "Asteroid Mathilde"             3 "REGION_ASTEROID_BELT" 8 182  50  834
write_tres 36 "16 Psyche"                     3 "REGION_ASTEROID_BELT" 8 190  50  884
write_tres 37 "4 Vesta"                       3 "REGION_ASTEROID_BELT" 8 198  50  934
write_tres 38 "Ceres (Ahuna Mons)"            3 "REGION_ASTEROID_BELT" 8 206  50  984
write_tres 39 "Hilda Group"                   3 "REGION_ASTEROID_BELT" 8 214  50 1034
write_tres 40 "Jupiter Trojans"               3 "REGION_ASTEROID_BELT" 8 222  50 1084

# D_041~D_050: Jovian T4
write_tres 41 "Jupiter Magnetosphere"         4 "REGION_JOVIAN"        9 240  55 1134
write_tres 42 "Great Red Spot"                4 "REGION_JOVIAN"        9 255  58 1189
write_tres 43 "Jovian Ring System"            4 "REGION_JOVIAN"        9 270  60 1247
write_tres 44 "Amalthea"                      4 "REGION_JOVIAN"        9 285  62 1307
write_tres 45 "Io"                            4 "REGION_JOVIAN"        9 300  65 1369
write_tres 46 "Pele Volcano (Io)"             4 "REGION_JOVIAN"        9 315  67 1434
write_tres 47 "Europa"                        4 "REGION_JOVIAN"        9 330  70 1501
write_tres 48 "Ganymede"                      4 "REGION_JOVIAN"        9 345  72 1571
write_tres 49 "Callisto"                      4 "REGION_JOVIAN"        9 360  75 1643
write_tres 50 "Outer Jovian System"           4 "REGION_JOVIAN"        9 375  78 1718

# D_051~D_060: Saturnian T4
write_tres 51 "Saturn Orbit"                  4 "REGION_SATURNIAN"     9 390  80 1796
write_tres 52 "Saturn Rings A-F"              4 "REGION_SATURNIAN"     9 405  82 1876
write_tres 53 "Hexagon Storm"                 4 "REGION_SATURNIAN"     9 420  84 1958
write_tres 54 "Pan, Shepherd Moon"            4 "REGION_SATURNIAN"     9 435  86 2042
write_tres 55 "Mimas"                         4 "REGION_SATURNIAN"     9 450  88 2128
write_tres 56 "Enceladus"                     4 "REGION_SATURNIAN"     9 465  90 2216
write_tres 57 "Tethys"                        4 "REGION_SATURNIAN"     9 480  92 2306
write_tres 58 "Dione"                         4 "REGION_SATURNIAN"     9 495  94 2398
write_tres 59 "Rhea"                          4 "REGION_SATURNIAN"     9 510  96 2492
write_tres 60 "Titan"                         4 "REGION_SATURNIAN"     9 525 100 2588

# D_061~D_070: Ice Giants T4
write_tres 61 "Iapetus"                       4 "REGION_ICE_GIANTS"    9 540 102 2688
write_tres 62 "Uranus Orbit"                  4 "REGION_ICE_GIANTS"    9 555 105 2790
write_tres 63 "Miranda"                       4 "REGION_ICE_GIANTS"    9 570 107 2895
write_tres 64 "Ariel and Umbriel"             4 "REGION_ICE_GIANTS"    9 585 110 3002
write_tres 65 "Titania and Oberon"            4 "REGION_ICE_GIANTS"    9 600 112 3112
write_tres 66 "Neptune Orbit"                 4 "REGION_ICE_GIANTS"    9 615 115 3224
write_tres 67 "Great Dark Spot"               4 "REGION_ICE_GIANTS"    9 630 117 3339
write_tres 68 "Triton"                        4 "REGION_ICE_GIANTS"    9 645 120 3456
write_tres 69 "Nereid"                        4 "REGION_ICE_GIANTS"    9 660 122 3576
write_tres 70 "Neptune Trojans"               4 "REGION_ICE_GIANTS"    9 675 125 3698

# D_071~D_080: Pluto and Kuiper Belt T5
write_tres 71 "Pluto"                         5 "REGION_PLUTO_KUIPER" 10 700 130 3823
write_tres 72 "Charon"                        5 "REGION_PLUTO_KUIPER" 10 720 132 3953
write_tres 73 "Nix and Hydra"                 5 "REGION_PLUTO_KUIPER" 10 740 134 4085
write_tres 74 "Arrokoth"                      5 "REGION_PLUTO_KUIPER" 10 760 136 4219
write_tres 75 "Haumea"                        5 "REGION_PLUTO_KUIPER" 10 780 138 4355
write_tres 76 "Makemake"                      5 "REGION_PLUTO_KUIPER" 10 800 140 4493
write_tres 77 "Eris"                          5 "REGION_PLUTO_KUIPER" 10 820 142 4633
write_tres 78 "Dysnomia"                      5 "REGION_PLUTO_KUIPER" 10 840 144 4775
write_tres 79 "Scattered Disc"                5 "REGION_PLUTO_KUIPER" 10 860 146 4919
write_tres 80 "Oort Cloud"                    5 "REGION_PLUTO_KUIPER" 10 880 150 5065

# D_081~D_090: Interstellar T5
write_tres 81 "Heliopause Crossing"           5 "REGION_INTERSTELLAR" 10 900 155 5215
write_tres 82 "Proxima Centauri"              5 "REGION_INTERSTELLAR" 10 920 158 5370
write_tres 83 "Proxima b"                     5 "REGION_INTERSTELLAR" 10 940 160 5528
write_tres 84 "Alpha Centauri AB"             5 "REGION_INTERSTELLAR" 10 960 163 5688
write_tres 85 "Barnard Star"                  5 "REGION_INTERSTELLAR" 10 980 165 5851
write_tres 86 "Sirius"                        5 "REGION_INTERSTELLAR" 10 1000 168 6016
write_tres 87 "Epsilon Eridani"               5 "REGION_INTERSTELLAR" 10 1020 170 6184
write_tres 88 "Gliese 581 System"             5 "REGION_INTERSTELLAR" 10 1040 172 6354
write_tres 89 "TRAPPIST-1 System"             5 "REGION_INTERSTELLAR" 10 1060 175 6526
write_tres 90 "Vega"                          5 "REGION_INTERSTELLAR" 10 1080 178 6701

# D_091~D_098: Milky Way Landmarks T5
write_tres 91 "Orion Nebula"                  5 "REGION_MILKY_WAY"    10 1100 180 6879
write_tres 92 "Horsehead Nebula"              5 "REGION_MILKY_WAY"    10 1120 183 7059
write_tres 93 "Pleiades Cluster"              5 "REGION_MILKY_WAY"    10 1140 185 7242
write_tres 94 "Betelgeuse"                    5 "REGION_MILKY_WAY"    10 1160 188 7427
write_tres 95 "Pillars of Creation"           5 "REGION_MILKY_WAY"    10 1180 190 7615
write_tres 96 "Magellanic Clouds"             5 "REGION_MILKY_WAY"    10 1200 192 7805
write_tres 97 "Crab Nebula"                   5 "REGION_MILKY_WAY"    10 1220 195 7997
write_tres 98 "Carina Nebula"                 5 "REGION_MILKY_WAY"    10 1240 198 8192

# D_099~D_100: Deep Space T5 (V1 ending; D_101~D_105 reserved for DLC)
write_tres 99  "Andromeda Galaxy"             5 "REGION_DEEP_SPACE"   10 1300 200 8390
write_tres 100 "Edge of Local Group"          5 "REGION_DEEP_SPACE"   10 1500 250 8590

echo "Generated $(ls "$DEST_DIR" | wc -l) destination .tres files"
