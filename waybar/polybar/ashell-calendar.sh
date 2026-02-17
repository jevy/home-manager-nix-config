#!/usr/bin/env bash

# Outputs JSON for ashell with upcoming meetings in the next hour
# Shows red color if any meeting is within 15 minutes
# Displays human-readable time until each meeting

# Read calendars from config file
CALENDARS=()
if [ -f "$HOME/.gcalclirc" ]; then
    while IFS= read -r line; do
        if [[ "$line" =~ ^--calendar= ]]; then
            cal=$(echo "$line" | sed 's/^--calendar=//;s/^"//;s/"$//')
            CALENDARS+=("--calendar=$cal")
        fi
    done < "$HOME/.gcalclirc"
fi

while true; do
    now_epoch=$(date +%s)
    current_year=$(date +%Y)
    today=$(date "+%a %b %-d")
    
    # Get all meetings - strip ANSI codes
    # Use explicit calendars from config
    if [ ${#CALENDARS[@]} -gt 0 ]; then
        agenda=$(gcalcli "${CALENDARS[@]}" agenda "now" "24 hours" --nocolor 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g')
    else
        agenda=$(gcalcli agenda "now" "24 hours" --nocolor 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g')
    fi
    
    if [ -z "$agenda" ] || [[ "$agenda" == *"No Events Found"* ]]; then
        echo '{"text": " No meetings", "alt": "empty", "class": "normal"}'
        sleep 60
        continue
    fi
    
    # Process meetings and find those within the next hour
    display_text=""
    has_urgent=false
    meeting_count=0
    current_date=""
    
    while IFS= read -r line; do
        # Skip empty lines and reminder lines
        [ -z "$line" ] && continue
        [[ "$line" == *"Reminder:"* ]] && continue

        # Check if line starts with a date header (e.g., "Tue Feb 17  ...")
        # gcalcli puts date + first event/all-day title on the same line
        if [[ "$line" =~ ^[A-Z][a-z]{2}\ [A-Z][a-z]{2}\ [0-9]{1,2} ]]; then
            current_date=$(echo "$line" | grep -oE '^[A-Z][a-z]{2} [A-Z][a-z]{2} [0-9]{1,2}')
            current_date="$current_date $current_year"
            # If this line has no time, it's an all-day event - skip
            if ! [[ "$line" =~ [0-9]{1,2}:[0-9]{2}[ap]m ]]; then
                continue
            fi
        fi

        # Check if it's an event line (contains time like "11:00am")
        if [[ "$line" =~ [0-9]{1,2}:[0-9]{2}[ap]m ]]; then
            # Extract first time match
            event_time=$(echo "$line" | grep -oE '[0-9]{1,2}:[0-9]{2}[ap]m' | head -1)
            # Strip date prefix (if any), first time, and surrounding spaces to get title
            event_title=$(echo "$line" | sed -E 's/^([A-Z][a-z]{2} [A-Z][a-z]{2} [0-9]{1,2})?[[:space:]]*[0-9]{1,2}:[0-9]{2}[ap]m[[:space:]]*//' | sed 's/[[:space:]]*$//' | cut -c1-20)
            
            if [ -z "$event_time" ] || [ -z "$event_title" ] || [ -z "$current_date" ]; then
                continue
            fi
            
            # Calculate event start time
            meeting_epoch=$(date -d "$current_date $event_time" +%s 2>/dev/null)
            
            if [ -z "$meeting_epoch" ]; then
                continue
            fi
            
            # Calculate minutes until meeting
            minutes_until=$(( (meeting_epoch - now_epoch) / 60 ))
            
            # Skip if more than 60 minutes away or started more than 15 min ago
            if [ "$minutes_until" -gt 60 ] || [ "$minutes_until" -lt -15 ]; then
                continue
            fi
            
            # Limit to 2 meetings
            if [ "$meeting_count" -ge 2 ]; then
                break
            fi
            
            # Format human-readable time
            if [ "$minutes_until" -le 0 ]; then
                time_until="now"
            elif [ "$minutes_until" -eq 1 ]; then
                time_until="1m"
            else
                time_until="${minutes_until}m"
            fi
            
            # Check if urgent (within 10 minutes and not passed)
            if [ "$minutes_until" -le 10 ] && [ "$minutes_until" -ge 0 ]; then
                has_urgent=true
            fi
            
            # Build display text
            if [ -n "$display_text" ]; then
                display_text="$display_text • "
            fi
            display_text="${display_text}${event_title} ${time_until}"
            
            meeting_count=$((meeting_count + 1))
        fi
    done <<< "$agenda"
    
    if [ -z "$display_text" ]; then
        echo '{"text": " No meetings soon", "alt": "empty", "class": "normal"}'
    elif [ "$has_urgent" = true ]; then
        echo "{\"text\": \"$display_text\", \"alt\": \"urgent\", \"class\": \"urgent\"}"
    else
        echo "{\"text\": \"$display_text\", \"alt\": \"calendar\", \"class\": \"normal\"}"
    fi
    
    # Update every 60 seconds
    sleep 60
done
