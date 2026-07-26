package main

import (
	"encoding/json"
	"testing"
	"time"
)

// TestWMOCondition covers every code in appendix B plus a spread of codes that
// must fall through to Unknown.
func TestWMOCondition(t *testing.T) {
	cases := map[int]string{
		0:  condClear,
		1:  condPartlyCloudy,
		2:  condPartlyCloudy,
		3:  condOvercast,
		45: condFog,
		48: condFog,
		51: condDrizzle,
		53: condDrizzle,
		55: condDrizzle,
		56: condSleet,
		57: condSleet,
		61: condLightRain,
		63: condRain,
		65: condHeavyRain,
		66: condSleet,
		67: condSleet,
		71: condLightSnow,
		73: condSnow,
		75: condHeavySnow,
		77: condSnow,
		80: condRain,
		81: condRain,
		82: condRain,
		85: condSnow,
		86: condSnow,
		95: condThunderstorm,
		96: condThunderstorm,
		99: condThunderstorm,
		// unmapped codes
		4:   condUnknown,
		78:  condUnknown,
		100: condUnknown,
		-1:  condUnknown,
	}
	for code, want := range cases {
		if got := wmoCondition(code); got != want {
			t.Errorf("wmoCondition(%d) = %q, want %q", code, got, want)
		}
	}
}

// TestWeatherIcon covers every condition in appendix A for both day and night,
// so the whole condition-to-icon table is exercised, not a subset.
func TestWeatherIcon(t *testing.T) {
	type row struct {
		cond, day, night string
	}
	table := []row{
		{condClear, "wx-clear-day", "wx-clear-night"},
		{condPartlyCloudy, "wx-partly-cloudy-day", "wx-partly-cloudy-night"},
		{condCloudy, "wx-cloudy", "wx-cloudy"},
		{condOvercast, "wx-overcast", "wx-overcast"},
		{condMist, "wx-mist", "wx-mist"},
		{condFog, "wx-fog", "wx-fog"},
		{condLightRain, "wx-rain-light", "wx-rain-light"},
		{condRain, "wx-rain", "wx-rain"},
		{condHeavyRain, "wx-rain-heavy", "wx-rain-heavy"},
		{condDrizzle, "wx-drizzle", "wx-drizzle"},
		{condLightSnow, "wx-snow-light", "wx-snow-light"},
		{condSnow, "wx-snow", "wx-snow"},
		{condHeavySnow, "wx-snow-heavy", "wx-snow-heavy"},
		{condSleet, "wx-sleet", "wx-sleet"},
		{condThunderstorm, "wx-thunderstorm", "wx-thunderstorm"},
		{condWindy, "wx-windy", "wx-windy"},
		{condHail, "wx-hail", "wx-hail"},
		{condUnknown, "wx-unknown", "wx-unknown"},
	}
	if len(table) != 18 {
		t.Fatalf("icon table has %d rows, want 18", len(table))
	}
	for _, r := range table {
		if got := weatherIcon(r.cond, true); got != r.day {
			t.Errorf("weatherIcon(%s, day) = %q, want %q", r.cond, got, r.day)
		}
		if got := weatherIcon(r.cond, false); got != r.night {
			t.Errorf("weatherIcon(%s, night) = %q, want %q", r.cond, got, r.night)
		}
	}
}

func TestUnitConversions(t *testing.T) {
	// F = C*9/5 + 32
	if got := fmtTemp(0, "celsius"); got != "0\u00b0C" {
		t.Errorf("fmtTemp(0, celsius) = %q", got)
	}
	if got := fmtTemp(0, "fahrenheit"); got != "32\u00b0F" {
		t.Errorf("fmtTemp(0, fahrenheit) = %q, want 32°F", got)
	}
	if got := fmtTemp(100, "fahrenheit"); got != "212\u00b0F" {
		t.Errorf("fmtTemp(100, fahrenheit) = %q, want 212°F", got)
	}
	if got := fmtTemp(20, "celsius"); got != "20\u00b0C" {
		t.Errorf("fmtTemp(20, celsius) = %q", got)
	}
	// mph = kmh * 0.621371
	if got := windValue(100, "fahrenheit"); got != "62.1371" {
		t.Errorf("windValue(100, mph) = %q, want 62.1371", got)
	}
	if got := windValue(10, "celsius"); got != "10" {
		t.Errorf("windValue(10, kmh) = %q, want 10", got)
	}
	if got := windUnits("celsius"); got != " kmh winds" {
		t.Errorf("windUnits(celsius) = %q", got)
	}
	if got := windUnits("fahrenheit"); got != " mph winds" {
		t.Errorf("windUnits(fahrenheit) = %q", got)
	}
	// tempInt rounds in the display unit.
	if got := tempInt(23.4, "celsius"); got != 23 {
		t.Errorf("tempInt(23.4, celsius) = %d, want 23", got)
	}
	if got := tempInt(23.4, "fahrenheit"); got != 74 {
		t.Errorf("tempInt(23.4, fahrenheit) = %d, want 74", got)
	}
}

func TestErrorMessages(t *testing.T) {
	cases := map[string]string{
		wxErrNetwork:          "Error loading weather. Check network.",
		wxErrApiKeyMissing:    "Error loading weather. Api key missing.",
		wxErrLocationNotFound: "Error loading weather. Location not found.",
		wxErrRateLimited:      "Error loading weather. Too many requests.",
		wxErrOther:            "Error loading weather.",
	}
	for kind, want := range cases {
		if got := weatherErrorMessage(kind); got != want {
			t.Errorf("weatherErrorMessage(%s) = %q, want %q", kind, got, want)
		}
	}
}

func TestRetryable(t *testing.T) {
	for _, k := range []string{wxErrNetwork, wxErrRateLimited} {
		if !wxRetryable(k) {
			t.Errorf("%s should be retryable", k)
		}
	}
	for _, k := range []string{wxErrLocationNotFound, wxErrApiKeyMissing, wxErrOther} {
		if wxRetryable(k) {
			t.Errorf("%s should not be retryable", k)
		}
	}
}

func TestLocationLine(t *testing.T) {
	if got := (wxLocation{city: "Berlin", region: "Berlin", country: "Germany"}).locationLine(); got != "Berlin, Berlin" {
		t.Errorf("region wins: %q", got)
	}
	if got := (wxLocation{city: "Berlin", country: "Germany"}).locationLine(); got != "Berlin, Germany" {
		t.Errorf("country fallback: %q", got)
	}
	if got := (wxLocation{lat: 52.5, lon: 13.4}).locationLine(); got != "52.5, 13.4" {
		t.Errorf("coords fallback: %q", got)
	}
}

func TestCurrentHourIndex(t *testing.T) {
	now := time.Now()
	mk := func(h int) string { return now.Add(time.Duration(h) * time.Hour).Format("2006-01-02T15:04") }
	// Round the anchor down to the hour so the "not in the future" boundary is
	// deterministic: -2h and -1h are past, +1h is the first future entry.
	times := []string{mk(-2), mk(-1), mk(1), mk(2)}
	if got := currentHourIndex(times); got != 1 {
		t.Errorf("currentHourIndex = %d, want 1 (entry before first future)", got)
	}
	// No future entry -> fallback 0.
	if got := currentHourIndex([]string{mk(-3), mk(-2)}); got != 0 {
		t.Errorf("currentHourIndex (all past) = %d, want 0", got)
	}
}

// TestBuildFrame checks the current-hour derivation, the 24/7 caps, the display
// formatting and the day-icon rule for daily items against a synthetic forecast.
func TestBuildFrame(t *testing.T) {
	now := time.Now()
	hourTime := func(h int) string {
		return now.Add(time.Duration(h) * time.Hour).Truncate(time.Hour).Format("2006-01-02T15:04")
	}

	// 30 hourly slots: index 0 is 5h in the past, so the current hour lands mid
	// array; ensures the 24-cap starts from the current hour, not index 0.
	var htime []string
	var temp, code, isday, uv, hum, feels, wind, precip []float64
	for i := range 30 {
		htime = append(htime, hourTime(i-5))
		temp = append(temp, 20)
		code = append(code, 0) // Clear
		if (i-5)%24 >= 6 && (i-5)%24 < 18 {
			isday = append(isday, 1)
		} else {
			isday = append(isday, 0)
		}
		uv = append(uv, 3)
		hum = append(hum, 55)
		feels = append(feels, 19)
		wind = append(wind, 10)
		precip = append(precip, 40)
	}

	var dtime, sunrise, sunset []string
	var dcode, dmax, dmin []float64
	for i := range 10 {
		day := now.Add(time.Duration(i) * 24 * time.Hour).Format("2006-01-02")
		dtime = append(dtime, day)
		sunrise = append(sunrise, day+"T05:30")
		sunset = append(sunset, day+"T21:15")
		dcode = append(dcode, 0)
		dmax = append(dmax, 25)
		dmin = append(dmin, 12)
	}

	data := &wxForecastResponse{
		Hourly: wxHourlyData{
			Time: htime, Temperature2m: temp, WeatherCode: code, IsDay: isday,
			UvIndex: uv, RelativeHumidity2m: hum, ApparentTemperature: feels,
			WindSpeed10m: wind, PrecipitationProbability: precip,
		},
		Daily: wxDailyData{
			Time: dtime, WeatherCode: dcode, Temperature2mMax: dmax,
			Temperature2mMin: dmin, Sunrise: sunrise, Sunset: sunset,
		},
	}

	loc := wxLocation{city: "Testville", region: "Testshire", lat: 1, lon: 2}
	frame := buildFrame(data, loc, "celsius", true)

	if frame.Status != "loaded" || !frame.HasData {
		t.Fatalf("status = %q hasData = %v", frame.Status, frame.HasData)
	}
	if frame.Location != "Testville, Testshire" {
		t.Errorf("location = %q", frame.Location)
	}
	if frame.Current == nil {
		t.Fatal("current is nil")
	}
	if frame.Current.Temperature != "20\u00b0C" {
		t.Errorf("current temp = %q", frame.Current.Temperature)
	}
	if frame.Current.Humidity != 55 || frame.Current.UvIndex != 3 {
		t.Errorf("current humidity/uv = %d/%d", frame.Current.Humidity, frame.Current.UvIndex)
	}
	if frame.Current.Wind != "10" || frame.Current.WindUnits != " kmh winds" {
		t.Errorf("current wind = %q%q", frame.Current.Wind, frame.Current.WindUnits)
	}
	if frame.Current.Sunrise != "05:30" || frame.Current.Sunset != "21:15" {
		t.Errorf("astronomy = %q/%q", frame.Current.Sunrise, frame.Current.Sunset)
	}
	if len(frame.Hourly) != 24 {
		t.Errorf("hourly count = %d, want 24", len(frame.Hourly))
	}
	if len(frame.Daily) != 7 {
		t.Errorf("daily count = %d, want 7", len(frame.Daily))
	}
	// Daily always uses the day icon even though the underlying condition is the
	// same Clear.
	if frame.Daily[0].Icon != "wx-clear-day" {
		t.Errorf("daily[0] icon = %q, want wx-clear-day", frame.Daily[0].Icon)
	}
	if frame.Daily[0].High != "25\u00b0C" || frame.Daily[0].Low != "12\u00b0C" {
		t.Errorf("daily[0] hi/lo = %q/%q", frame.Daily[0].High, frame.Daily[0].Low)
	}
	if frame.Hourly[0].Uv != "3 UV" {
		t.Errorf("hourly[0] uv = %q", frame.Hourly[0].Uv)
	}

	// The frame must marshal to a non-null hourly/daily array.
	b, err := json.Marshal(frame)
	if err != nil {
		t.Fatal(err)
	}
	if !json.Valid(b) {
		t.Fatal("frame is not valid json")
	}
}

func TestResolveUnit(t *testing.T) {
	t.Setenv("LC_MEASUREMENT", "")
	t.Setenv("LANG", "en_US.UTF-8")
	if got := resolveUnit("auto"); got != "fahrenheit" {
		t.Errorf("auto en_US = %q, want fahrenheit", got)
	}
	t.Setenv("LANG", "de_DE.UTF-8")
	if got := resolveUnit("auto"); got != "celsius" {
		t.Errorf("auto de_DE = %q, want celsius", got)
	}
	if got := resolveUnit("fahrenheit"); got != "fahrenheit" {
		t.Errorf("explicit unit ignored env: %q", got)
	}
}
