#!/bin/bash
LAYOUT=$(hyprctl getoption general:layout -j | jq -r '.str')

if [ "$LAYOUT" = "scrolling" ]; then
    hyprctl keyword general:layout dwindle
else
    hyprctl keyword general:layout scrolling
fi

