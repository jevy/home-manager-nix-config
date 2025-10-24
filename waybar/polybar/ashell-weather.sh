#!/bin/sh

weather_output=$(~/.config/polybar-scripts/openweathermap-forecast.sh)

if [ -n "$weather_output" ]; then
    echo "{\"text\": \"$weather_output\", \"alt\": \"weather\"}"
else
    echo "{\"text\": \"Weather unavailable\", \"alt\": \"error\"}"
fi