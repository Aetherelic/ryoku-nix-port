function batteryGlyph(pct, charging) {
    const level = pct > 99 ? 100 : pct > 90 ? 90 : pct > 80 ? 80 : pct > 70 ? 70
        : pct > 60 ? 60 : pct > 50 ? 50 : pct > 40 ? 40 : pct > 30 ? 30
        : pct > 20 ? 20 : pct > 10 ? 10 : 0;
    return "battery-level-" + level + (charging ? "-charging" : "");
}

function profileLabel(name) {
    return name === "power-saver" ? "Power Saver"
        : name === "balanced" ? "Balanced"
        : name === "performance" ? "Performance"
        : name;
}

function duration(seconds) {
    const value = Math.max(0, Math.floor(seconds));
    const minutes = Math.floor(value / 60);
    const rest = value % 60;
    return minutes + ":" + (rest < 10 ? "0" : "") + rest;
}

function weatherIcon(code, day) {
    const phase = day ? "day" : "night";
    if (code === 0) return "weather-clear-" + phase;
    if (code === 1 || code === 2) return "weather-partly-cloudy-" + phase;
    if (code === 3) return "weather-overcast";
    if (code === 45 || code === 48) return "weather-fog";
    if (code >= 51 && code <= 57) return "weather-drizzle";
    if (code === 61 || code === 80) return "weather-rain-light";
    if (code === 63 || code === 81) return "weather-rain";
    if (code === 65 || code === 82) return "weather-rain-heavy";
    if (code === 66 || code === 67) return "weather-sleet";
    if (code === 71 || code === 85) return "weather-snow-light";
    if (code === 73 || code === 77) return "weather-snow";
    if (code === 75 || code === 86) return "weather-snow-heavy";
    if (code >= 95) return "weather-thunderstorm";
    return "weather-cloudy";
}

if (typeof module !== "undefined" && module.exports)
    module.exports = { batteryGlyph, profileLabel, duration, weatherIcon };
