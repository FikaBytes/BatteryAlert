#!/bin/bash

SOUND="/Users/your_login/alarm_single.wav"
THRESHOLD=20
CHECK_INTERVAL=300   # seconds between battery checks
MAX_BEEPS=100         # failsafe: max number of beeps per discharge episode

ALERTED=0             # tracks whether the dialog was already shown for the current low-battery episode

while true; do
    BATT_INFO=$(pmset -g batt)
    BATTERY=$(echo "$BATT_INFO" | grep -o '[0-9]*%' | tr -d '%')
    STATUS=$(echo "$BATT_INFO" | grep -o "discharging\|charging\|charged" | head -1)

    # Not discharging (charging/charged) -> nothing to do, reset the alert flag and wait
    if [ "$STATUS" != "discharging" ]; then
        ALERTED=0
        sleep "$CHECK_INTERVAL"
        continue
    fi

    if [ "$BATTERY" -le "$THRESHOLD" ]; then
        # Show the dialog only once per discharge episode, not every failsafe restart
        if [ "$ALERTED" -eq 0 ]; then
            osascript -e 'display dialog "Connect to power!\n'"$BATTERY"'% remaining" with title "Low battery" buttons {"OK"} default button "OK"' &
            ALERTED=1
        fi

        # audio repeats until charger is connected, battery recovers, or MAX_BEEPS is reached (failsafe)
        COUNT=0
        while [ "$STATUS" = "discharging" ] && [ "$BATTERY" -le "$THRESHOLD" ] && [ $COUNT -lt $MAX_BEEPS ]; do
            afplay "$SOUND" &
            SOUND_PID=$!
            wait $SOUND_PID
            COUNT=$((COUNT + 1))
            BATT_INFO=$(pmset -g batt)
            BATTERY=$(echo "$BATT_INFO" | grep -o '[0-9]*%' | tr -d '%')
            STATUS=$(echo "$BATT_INFO" | grep -o "discharging\|charging\|charged" | head -1)
        done
    fi

    sleep "$CHECK_INTERVAL"
done
