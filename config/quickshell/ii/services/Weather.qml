pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import QtPositioning

import qs.modules.common

Singleton {
    id: root
    // 10 minute
    readonly property int fetchInterval: Config.options.bar.weather.fetchInterval * 60 * 1000
    readonly property string city: Config.options.bar.weather.city
    readonly property bool useUSCS: Config.options.bar.weather.useUSCS
    property bool gpsActive: Config.options.bar.weather.enableGPS

    onUseUSCSChanged: {
        root.getData();
    }
    onCityChanged: {
        root.getData();
    }

    property var location: ({
        valid: false,
        lat: 0,
        lon: 0
    })

    property var data: ({
        uv: 0,
        humidity: 0,
        sunrise: 0,
        sunset: 0,
        windDir: 0,
        wCode: 0,
        city: 0,
        wind: 0,
        precip: 0,
        visib: 0,
        press: 0,
        temp: 0,
        tempFeelsLike: 0,
        lastRefresh: 0,
    })

    function refineData(data) {
        let temp = {};
        temp.uv = data?.current?.uvIndex || 0;
        temp.humidity = (data?.current?.humidity || 0) + "%";
        temp.sunrise = data?.astronomy?.sunrise || "0.0";
        temp.sunset = data?.astronomy?.sunset || "0.0";
        temp.windDir = data?.current?.winddir16Point || "N";
        temp.wCode = data?.current?.weatherCode || "113";
        temp.city = data?.location?.areaName[0]?.value || "City";
        temp.temp = "";
        temp.tempFeelsLike = "";
        if (root.useUSCS) {
            temp.wind = (data?.current?.windspeedMiles || 0) + " mph";
            temp.precip = (data?.current?.precipInches || 0) + " in";
            temp.visib = (data?.current?.visibilityMiles || 0) + " m";
            temp.press = (data?.current?.pressureInches || 0) + " psi";
            temp.temp += root.formatTemp(data?.current?.temp_F, data?.precise?.temperature_2m);
            temp.tempFeelsLike += root.formatTemp(data?.current?.FeelsLikeF, data?.precise?.apparent_temperature);
            temp.temp += "°F";
            temp.tempFeelsLike += "°F";
        } else {
            temp.wind = (data?.current?.windspeedKmph || 0) + " km/h";
            temp.precip = (data?.current?.precipMM || 0) + " mm";
            temp.visib = (data?.current?.visibility || 0) + " km";
            temp.press = (data?.current?.pressure || 0) + " hPa";
            temp.temp += root.formatTemp(data?.current?.temp_C, data?.precise?.temperature_2m);
            temp.tempFeelsLike += root.formatTemp(data?.current?.FeelsLikeC, data?.precise?.apparent_temperature);
            temp.temp += "°C";
            temp.tempFeelsLike += "°C";
        }
        temp.lastRefresh = DateTime.time + " • " + DateTime.date;
        root.data = temp;
    }

    // Rundet auf ganze Grad. Nur wenn dabei 0 rauskommt, wird eine
    // Nachkommastelle angezeigt (z. B. -0.3), Wert von Open-Meteo.
    // Nie mehr "-0".
    function formatTemp(raw, precise) {
        const r = Math.round(Number(raw)) || 0;
        const p = Number(precise);
        if (r === 0 && precise !== undefined && precise !== null && !isNaN(p)) {
            return ((Math.round(p * 10) / 10) || 0).toFixed(1);
        }
        return String(r);
    }

    function getData() {
        let url = "wttr.in";

        if (root.gpsActive && root.location.valid) {
            url += `/${root.location.lat},${root.location.long}`;
        } else {
            url += `/${formatCityName(root.city)}`;
        }
        url += "?format=j1";

        const keys = root.useUSCS ? "[.temp_F, .FeelsLikeF]" : "[.temp_C, .FeelsLikeC]";
        const unit = root.useUSCS ? "&temperature_unit=fahrenheit" : "";

        // wttr.in liefert nur ganze Grad. Steht dort 0 (oder "-0"), holen wir
        // uns den genauen Wert mit Nachkommastelle von Open-Meteo.
        let command = `w=$(curl -s '${url}'); `;
        command += `p=null; `;
        command += `if printf '%s' "$w" | jq -e '.current_condition[0] | ${keys} | map(tonumber) | any(. == 0)' >/dev/null 2>&1; then `;
        command += `lat=$(printf '%s' "$w" | jq -r '.nearest_area[0].latitude'); `;
        command += `lon=$(printf '%s' "$w" | jq -r '.nearest_area[0].longitude'); `;
        command += `p=$(curl -s --max-time 5 "https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,apparent_temperature${unit}" | jq -c '.current // null' 2>/dev/null); `;
        command += `[ -n "$p" ] || p=null; `;
        command += `fi; `;
        // only take the current weather, location, astronomy data (+ precise temp)
        command += `printf '%s' "$w" | jq --argjson p "$p" '{current: .current_condition[0], location: .nearest_area[0], astronomy: .weather[0].astronomy[0], precise: $p}'`;
        fetcher.command[2] = command;
        fetcher.running = true;
    }

    function formatCityName(cityName) {
        return cityName.trim().split(/\s+/).join('+');
    }

    Component.onCompleted: {
        if (!root.gpsActive) return;
        console.info("[WeatherService] Starting the GPS service.");
        positionSource.start();
    }

    Process {
        id: fetcher
        command: ["bash", "-c", ""]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0)
                    return;
                try {
                    const parsedData = JSON.parse(text);
                    root.refineData(parsedData);
                    // console.info(`[ data: ${JSON.stringify(parsedData)}`);
                } catch (e) {
                    console.error(`[WeatherService] ${e.message}`);
                }
            }
        }
    }

    PositionSource {
        id: positionSource
        updateInterval: root.fetchInterval

        onPositionChanged: {
            // update the location if the given location is valid
            // if it fails getting the location, use the last valid location
            if (position.latitudeValid && position.longitudeValid) {
                root.location.lat = position.coordinate.latitude;
                root.location.long = position.coordinate.longitude;
                root.location.valid = true;
                // console.info(`📍 Location: ${position.coordinate.latitude}, ${position.coordinate.longitude}`);
                root.getData();
                // if can't get initialized with valid location deactivate the GPS
            } else {
                root.gpsActive = root.location.valid ? true : false;
                console.error("[WeatherService] Failed to get the GPS location.");
            }
        }

        onValidityChanged: {
            if (!positionSource.valid) {
                positionSource.stop();
                root.location.valid = false;
                root.gpsActive = false;
                Quickshell.execDetached(["notify-send", Translation.tr("Weather Service"), Translation.tr("Cannot find a GPS service. Using the fallback method instead."), "-a", "Shell"]);
                console.error("[WeatherService] Could not aquire a valid backend plugin.");
            }
        }
    }

    Timer {
        running: !root.gpsActive
        repeat: true
        interval: root.fetchInterval
        triggeredOnStart: !root.gpsActive
        onTriggered: root.getData()
    }
}
