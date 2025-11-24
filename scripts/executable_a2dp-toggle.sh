#!/usr/bin/env bash

# Automatically toggle audio profile for any connected Bluetooth headset.
# Logging is in English, and notify-send is used to show the selected profile with a Bluetooth icon.

ICON="bluetooth" # Change to e.g. "audio-headphones-bluetooth" if desired

# Find first connected Bluetooth audio card (bluez_card.*)
CARD=$(pactl list cards short | awk '/bluez_card/ {print $2; exit}')

if [[ -z "$CARD" ]]; then
  echo "No Bluetooth audio device detected."
  notify-send -i "$ICON" "Bluetooth Profile" "No Bluetooth audio device detected."
  exit 1
fi

echo "Using Bluetooth card: $CARD"

# Read current active profile
CURRENT_PROFILE=$(pactl list cards | awk -v card="$CARD" '
    $0 ~ "Name: "card {in_card=1}
    in_card && /Active Profile/ {print $3; exit}
')

echo "Current profile: $CURRENT_PROFILE"

# Define preferred profile order
A2DP_PROFILES=("a2dp-sink" "a2dp-sink-sbc_xq" "a2dp-sink-sbc")
HSP_PROFILES=("headset-head-unit-msbc" "headset-head-unit" "headset-head-unit-cvsd")

# Read card info to confirm available profiles
AVAILABLE=$(pactl list cards | sed -n "/Name: $CARD/,/Ports:/p")

# Helper to switch profile + show notification
set_profile() {
  PROFILE="$1"
  echo "Switching to: $PROFILE"
  if pactl set-card-profile "$CARD" "$PROFILE"; then
    notify-send -i "$ICON" "Bluetooth Audio Profile" "Switched to: $PROFILE"
    exit 0
  else
    echo "Failed to switch to profile: $PROFILE"
    notify-send -i "$ICON" "Bluetooth Audio Profile" "Failed to switch to: $PROFILE"
    exit 1
  fi
}

# If current profile is A2DP -> switch to HSP
for p in "${A2DP_PROFILES[@]}"; do
  if [[ "$CURRENT_PROFILE" == "$p" ]]; then
    echo "Detected A2DP profile. Switching to best available HSP/HFP..."
    for hsp in "${HSP_PROFILES[@]}"; do
      echo "$AVAILABLE" | grep -q "$hsp" && set_profile "$hsp"
    done
  fi
done

# If current profile is HSP -> switch to A2DP
for p in "${HSP_PROFILES[@]}"; do
  if [[ "$CURRENT_PROFILE" == "$p" ]]; then
    echo "Detected HSP/HFP profile. Switching to best available A2DP..."
    for a2dp in "${A2DP_PROFILES[@]}"; do
      echo "$AVAILABLE" | grep -q "$a2dp" && set_profile "$a2dp"
    done
  fi
done

echo "No valid profile to switch to."
notify-send -i "$ICON" "Bluetooth Audio Profile" "No valid profile to switch to."
exit 1
