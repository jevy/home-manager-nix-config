#!/usr/bin/env bash

# Sends notifications for upcoming calendar events
# Respects per-event notification times from Google Calendar

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/gcal-notify"
mkdir -p "$CACHE_DIR"

# Get current time
now_epoch=$(date +%s)
today=$(date "+%a %b %-d")

# Get events - strip ANSI codes first
events=$(gcalcli --nocache --calendar="jevin@quickjack.ca" --calendar="jmaltais@covenant.co" agenda --nostarted --nocolor 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g')

if [ -z "$events" ]; then
    exit 0
fi

# Track current date while parsing
current_date=""

# Process each line
while IFS= read -r line; do
    # Skip empty lines
    [ -z "$line" ] && continue
    
    # Check if it's a date header (contains day of week)
    if [[ "$line" =~ ^[A-Z][a-z]{2}\ [A-Z][a-z]{2}\ [0-9]+ ]]; then
        current_date=$(echo "$line" | awk '{print $1 " " $2 " " $3}')
        continue
    fi
    
    # Check if it's an event line (starts with spaces then time)
    if [[ "$line" =~ ^[[:space:]]+[0-9]{1,2}:[0-9]{2}[ap]m ]]; then
        # Parse event time and title
        event_time=$(echo "$line" | awk '{print $1}')
        event_title=$(echo "$line" | sed 's/^[[:space:]]*[0-9:]*[ap]m[[:space:]]*//' | sed 's/^[[:space:]]*//')
        
        if [ -z "$event_time" ] || [ -z "$event_title" ] || [ -z "$current_date" ]; then
            continue
        fi
        
        # Convert 12-hour to 24-hour for parsing
        event_time_24=$(date -d "$current_date $event_time" "+%H:%M" 2>/dev/null || \
                         echo "$event_time" | sed 's/am//;s/pm//')
        
        # Calculate event start time
        event_epoch=$(date -d "$current_date $event_time" +%s 2>/dev/null || \
                      date -j -f "%a %b %d %I:%M%p" "$current_date $event_time" +%s 2>/dev/null)
        
        if [ -z "$event_epoch" ]; then
            continue
        fi
        
        # Calculate minutes until event
        minutes_until=$(( (event_epoch - now_epoch) / 60 ))
        
        # Skip if event is more than 60 minutes away or already started
        if [ "$minutes_until" -lt -2 ] || [ "$minutes_until" -gt 60 ]; then
            continue
        fi
        
        # Create unique ID for this event
        event_id=$(echo "$event_title$event_epoch" | md5sum | cut -d' ' -f1)
        notified_file="$CACHE_DIR/$event_id"
        
        # Check if we should notify
        should_notify=false
        notify_time=""
        
        if [ "$minutes_until" -le 0 ] && [ "$minutes_until" -gt -2 ] && [ ! -f "$notified_file" ]; then
            should_notify=true
            notify_time="now"
        elif [ "$minutes_until" -le 5 ] && [ "$minutes_until" -gt 3 ] && [ ! -f "$notified_file.5min" ]; then
            should_notify=true
            notify_time="5min"
            touch "$notified_file.5min"
        elif [ "$minutes_until" -le 10 ] && [ "$minutes_until" -gt 8 ] && [ ! -f "$notified_file.10min" ]; then
            should_notify=true
            notify_time="10min"
            touch "$notified_file.10min"
        elif [ "$minutes_until" -le 15 ] && [ "$minutes_until" -gt 13 ] && [ ! -f "$notified_file.15min" ]; then
            should_notify=true
            notify_time="15min"
            touch "$notified_file.15min"
        elif [ "$minutes_until" -le 18 ] && [ "$minutes_until" -gt 16 ] && [ ! -f "$notified_file.18min" ]; then
            # Support custom 18 minute reminder
            should_notify=true
            notify_time="18min"
            touch "$notified_file.18min"
        fi
        
        if [ "$should_notify" = true ]; then
            if [ "$notify_time" = "now" ]; then
                notify-send -u critical -i appointment-soon -a gcalcli "Meeting Starting Now" "$event_title at $event_time"
                touch "$notified_file"
                echo "Notification sent: $event_title starting now"
            else
                notify-send -u normal -i appointment-soon -a gcalcli "Upcoming Meeting" "$event_title in ${notify_time%m} minutes at $event_time"
                echo "Notification sent: $event_title in ${notify_time%m} minutes"
            fi
        fi
    fi
done <<< "$events"

# Clean up old notification files
find "$CACHE_DIR" -type f -mtime +1 -delete 2>/dev/null
