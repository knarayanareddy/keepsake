#!/usr/bin/env bash
# Regenerates web/hero.png (the 1200x630 card image) from primitives — no browser, no design tool.
# It draws the app's own palette and states, and the numbers in it are read off the recorded
# match (web/demo-match.json: 20 txs, 1,532,906 gas), so if the rules move, the image is
# regenerated rather than hand-edited into a lie.  Needs ImageMagick + DejaVu fonts.
#   ./script/make-hero.sh
set -e
B=60; C=32; G=16; E=$((B + C*G))
GRID=""; for i in $(seq 0 $G); do GRID="$GRID line $((B+i*C)) $B $((B+i*C)) $E line $B $((B+i*C)) $E $((B+i*C))"; done
AX=$((B+4*C+C/2)); AY=$((B+5*C+C/2)); BX=$((B+5*C+C/2)); BY=$AY
convert -size 1200x630 xc:'#07080c' \
  -stroke '#12141c' -strokewidth 1 -fill none -draw "$GRID" \
  -stroke '#22242e' -draw "rectangle $B $B $E $E" \
  -stroke '#d4b56a' -strokewidth 2 -fill none -draw "rectangle $((B+4*C)) $((B+5*C)) $((B+6*C)) $((B+6*C))" \
  -stroke none -fill '#d4b56a' -draw "circle $AX,$AY $AX,$((AY+11))" \
  -fill '#c45c4a' -draw "circle $BX,$BY $BX,$((BY+11))" \
  -fill '#8a8474' -font DejaVu-Sans-Mono -pointsize 13 -annotate +$B+606 "adjacent · both one shot from death · inside SPARE_WINDOW" \
  -stroke none -font DejaVu-Sans -pointsize 46 -fill '#e8e4d8' -annotate +640+136 "K E E P S A K E" \
  -stroke '#d4b56a' -draw "line 640 162 1152 162" \
  -stroke none -font DejaVu-Sans -pointsize 20 -fill '#8a8474' \
    -annotate +640+206 $'A 16x16 arena on Monad where the only\nwitness to what you did is the chain.' \
  -font DejaVu-Sans-Mono -pointsize 15 -fill '#d4b56a' -annotate +640+296 "the rule, enforced in the contract:" \
  -fill '#e8e4d8' \
    -annotate +640+326 "  spare  needs a real kill shot (<=2 hp, armed)" \
    -annotate +640+350 "  betray  carries refUID of your own pact" \
    -annotate +640+374 "  a kill  writes nothing. no record, no credit" \
    -annotate +640+398 "  one attester, pinned write-once, no admin call" \
  -fill '#8a8474' -pointsize 14 -annotate +640+440 $'player --pact|spare|shoot()--> World --attest()--> HonorLog' \
    -annotate +640+462 "        only caller accepted; everyone else reverts" \
  -fill '#e8e4d8' -pointsize 14 -annotate +640+500 $'each fact is an ERC-721 soulbound to its subject:' \
    -annotate +640+522 "2 contracts · 11 KB runtime · 16 tests · no tokens" \
  -fill '#c45c4a' -pointsize 12 -annotate +640+556 "MONAD BLITZ AMSTERDAM · TESTNET 10143 · 20 txs · 1.53M gas" \
  -fill '#7d9b6a' -pointsize 13 -annotate +640+584 "THE WORLD IS THE ONLY ATTESTER · YOU CANNOT CERTIFY YOURSELF" \
  web/hero.png
identify web/hero.png
