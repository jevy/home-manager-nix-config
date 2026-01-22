#!/bin/sh

get_icon() {
    case $1 in
        # Nerd Font weather icons (Material Design)
        01d) icon="󰖙";;  # sunny
        01n) icon="󰖔";;  # night clear
        02d) icon="󰖕";;  # partly cloudy day
        02n) icon="󰼱";;  # partly cloudy night
        03*) icon="󰖐";;  # cloudy
        04*) icon="󰖐";;  # broken clouds
        09*) icon="󰖖";;  # shower rain
        10d) icon="󰖗";;  # rain day
        10n) icon="󰖗";;  # rain night
        11*) icon="󰙾";;  # thunderstorm
        13*) icon="󰼶";;  # snow
        50*) icon="󰖑";;  # fog/mist
        *) icon="󰖐";;    # default cloudy
    esac

    echo $icon
}

source ~/secrets/weather_api_for_polybar
CITY="6094817"
UNITS="metric"
SYMBOL="°"

API="https://api.openweathermap.org/data/2.5"

if [ -n "$CITY" ]; then
    if [ "$CITY" -eq "$CITY" ] 2>/dev/null; then
        CITY_PARAM="id=$CITY"
    else
        CITY_PARAM="q=$CITY"
    fi

    current=$(curl -sf "$API/weather?appid=$KEY&$CITY_PARAM&units=$UNITS")
    forecast=$(curl -sf "$API/forecast?appid=$KEY&$CITY_PARAM&units=$UNITS&cnt=1")
else
    location=$(curl -sf https://location.services.mozilla.com/v1/geolocate?key=geoclue)

    if [ -n "$location" ]; then
        location_lat="$(echo "$location" | jq '.location.lat')"
        location_lon="$(echo "$location" | jq '.location.lng')"

        current=$(curl -sf "$API/weather?appid=$KEY&lat=$location_lat&lon=$location_lon&units=$UNITS")
        forecast=$(curl -sf "$API/forecast?appid=$KEY&lat=$location_lat&lon=$location_lon&units=$UNITS&cnt=1")
    fi
fi

if [ -n "$current" ] && [ -n "$forecast" ]; then
    current_temp=$(echo "$current" | jq ".main.feels_like" | cut -d "." -f 1)
    current_icon=$(echo "$current" | jq -r ".weather[0].icon")

    current_location=$(echo "$current" | jq -r ".name" )

    forecast_temp=$(echo "$forecast" | jq ".list[].main.feels_like" | cut -d "." -f 1)
    forecast_icon=$(echo "$forecast" | jq -r ".list[].weather[0].icon")

    if [ "$current_temp" -gt "$forecast_temp" ]; then
        trend=""
    elif [ "$forecast_temp" -gt "$current_temp" ]; then
        trend=""
    else
        trend=""
    fi

    echo "$current_location $(get_icon "$current_icon") $current_temp$SYMBOL  $trend  $(get_icon "$forecast_icon") $forecast_temp$SYMBOL"
fi
