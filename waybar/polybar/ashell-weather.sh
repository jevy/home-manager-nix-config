#!/bin/sh

while true; do
    weather_output=$(~/.config/polybar-scripts/openweathermap-forecast.sh)

    if [ -n "$weather_output" ]; then
        echo "{\"text\": \"$weather_output\", \"alt\": \"weather\"}"
        sleep 600
    else
        echo "{\"text\": \"Weather unavailable\", \"alt\": \"error\"}"
        sleep 15
    fi
done
