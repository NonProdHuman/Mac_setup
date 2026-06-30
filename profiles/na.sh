#!/usr/bin/env bash

set -e

echo "   -> Configuring NA power settings"

get_pmset_value() {
    local power_source="$1"
    local setting="$2"

    pmset -g custom | awk -v section="$power_source" -v key="$setting" '
        $0 ~ "^" section ":" {
            in_section = 1
            next
        }
        /^[[:alpha:] ][[:alpha:] ]+:$/ {
            in_section = 0
        }
        in_section && $1 == key {
            print $2
            exit
        }
    '
}

set_pmset_value() {
    local mode="$1"
    local power_source="$2"
    local setting="$3"
    local desired="$4"
    local current

    current=$(get_pmset_value "$power_source" "$setting")
    if [[ "$current" == "$desired" ]]; then
        echo "      ${power_source}: ${setting} already ${desired}"
    else
        echo "      ${power_source}: setting ${setting} to ${desired}"
        sudo pmset "$mode" "$setting" "$desired"
    fi
}

# Battery: sleep reasonably to preserve charge.
set_pmset_value -b "Battery Power" sleep 15
set_pmset_value -b "Battery Power" displaysleep 5
set_pmset_value -b "Battery Power" disksleep 10
set_pmset_value -b "Battery Power" powernap 0

# Power adapter: keep the Mac available while plugged in.
set_pmset_value -c "AC Power" sleep 0
set_pmset_value -c "AC Power" displaysleep 0
set_pmset_value -c "AC Power" disksleep 10
set_pmset_value -c "AC Power" powernap 0
set_pmset_value -c "AC Power" ttyskeepawake 1
set_pmset_value -c "AC Power" womp 1
