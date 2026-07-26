package main

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"net/http"
	"net/url"
	"os"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"
)

// weather.go owns the weather forecast the daemon fetches from Open-Meteo (the
// keyless public provider) and streams to QML on the "weather" state topic, so
// QML never makes an HTTP request itself. It reproduces the reference weather
// service exactly: the forecast and geocoding endpoints and their query
// parameters, the 15 minute poll, the retry ladder (3 attempts, 5 s doubling,
// 60 s on rate limit), the WMO-code to condition table, the condition to icon
// table with its day and night split, the five error strings, and the unit
// conversions (F = C*9/5+32, mph = kmh*0.621371). The forecast is always
// requested in celsius and km/h; the display unit is applied when formatting, so
// the same fetch serves either unit. Current conditions come from the hourly
// entry for the current hour (the endpoint requests no separate current block);
// hourly keeps 24 entries from that hour, daily keeps the first 7, and astronomy
// is the first daily entry's sunrise/sunset.
//
// Divergence from the reference (recorded): the reference default location is the
// null island (Coordinates 0,0). Ryoku instead falls back to a keyless IP lookup
// when no location is configured, so a fresh profile shows local weather rather
// than the Gulf of Guinea. An explicit location always wins over the fallback.

const (
	wxForecastURL  = "https://api.open-meteo.com/v1/forecast"
	wxGeocodingURL = "https://geocoding-api.open-meteo.com/v1/search"
	wxIPURL        = "http://ip-api.com/json/?fields=status,city,regionName,country,lat,lon"

	wxHourlyParams = "temperature_2m,relative_humidity_2m,apparent_temperature," +
		"precipitation_probability,precipitation,weather_code,cloud_cover,pressure_msl," +
		"visibility,wind_speed_10m,wind_direction_10m,wind_gusts_10m,dew_point_2m,uv_index,is_day"
	wxDailyParams = "weather_code,temperature_2m_max,temperature_2m_min," +
		"relative_humidity_2m_mean,sunrise,sunset,uv_index_max,precipitation_sum," +
		"precipitation_probability_max,wind_speed_10m_max"

	wxPollInterval = 15 * time.Minute
	wxMaxRetries   = 3
	wxRetryBase    = 5 * time.Second
	wxRateWait     = 60 * time.Second
	wxHTTPTimeout  = 10 * time.Second
)

// Weather conditions, reproduced from the reference WeatherCondition enum. Only
// the variants Open-Meteo can produce are ever emitted; Cloudy, Mist, Windy and
// Hail come from the reference's unused key-based providers and are kept in the
// icon table for completeness but never returned by wmoCondition.
const (
	condClear        = "Clear"
	condPartlyCloudy = "PartlyCloudy"
	condCloudy       = "Cloudy"
	condOvercast     = "Overcast"
	condMist         = "Mist"
	condFog          = "Fog"
	condLightRain    = "LightRain"
	condRain         = "Rain"
	condHeavyRain    = "HeavyRain"
	condDrizzle      = "Drizzle"
	condLightSnow    = "LightSnow"
	condSnow         = "Snow"
	condHeavySnow    = "HeavySnow"
	condSleet        = "Sleet"
	condThunderstorm = "Thunderstorm"
	condWindy        = "Windy"
	condHail         = "Hail"
	condUnknown      = "Unknown"
)

// Weather error kinds and their exact display strings (reference weather service).
const (
	wxErrNetwork          = "network"
	wxErrApiKeyMissing    = "apiKeyMissing"
	wxErrLocationNotFound = "locationNotFound"
	wxErrRateLimited      = "rateLimited"
	wxErrOther            = "other"
)

func weatherErrorMessage(kind string) string {
	switch kind {
	case wxErrNetwork:
		return "Error loading weather. Check network."
	case wxErrApiKeyMissing:
		return "Error loading weather. Api key missing."
	case wxErrLocationNotFound:
		return "Error loading weather. Location not found."
	case wxErrRateLimited:
		return "Error loading weather. Too many requests."
	default:
		return "Error loading weather."
	}
}

// wmoCondition maps an Open-Meteo WMO weather code to a condition (reference
// WeatherCondition::from_wmo_code, appendix B). Codes outside the table are
// Unknown.
func wmoCondition(code int) string {
	switch code {
	case 0:
		return condClear
	case 1, 2:
		return condPartlyCloudy
	case 3:
		return condOvercast
	case 45, 48:
		return condFog
	case 51, 53, 55:
		return condDrizzle
	case 56, 57:
		return condSleet
	case 61:
		return condLightRain
	case 63:
		return condRain
	case 65:
		return condHeavyRain
	case 66, 67:
		return condSleet
	case 71:
		return condLightSnow
	case 73:
		return condSnow
	case 75:
		return condHeavySnow
	case 77:
		return condSnow
	case 80, 81, 82:
		return condRain
	case 85, 86:
		return condSnow
	case 95:
		return condThunderstorm
	case 96, 99:
		return condThunderstorm
	default:
		return condUnknown
	}
}

// weatherIcon maps a condition and day/night flag to a Ryoku weather icon token
// (reference get_weather_icon_name, appendix A). Only Clear and PartlyCloudy
// split on day/night; every other condition uses one icon for both. Daily items
// always pass isDay=true.
func weatherIcon(condition string, isDay bool) string {
	switch condition {
	case condClear:
		if isDay {
			return "wx-clear-day"
		}
		return "wx-clear-night"
	case condPartlyCloudy:
		if isDay {
			return "wx-partly-cloudy-day"
		}
		return "wx-partly-cloudy-night"
	case condCloudy:
		return "wx-cloudy"
	case condOvercast:
		return "wx-overcast"
	case condMist:
		return "wx-mist"
	case condFog:
		return "wx-fog"
	case condLightRain:
		return "wx-rain-light"
	case condRain:
		return "wx-rain"
	case condHeavyRain:
		return "wx-rain-heavy"
	case condDrizzle:
		return "wx-drizzle"
	case condLightSnow:
		return "wx-snow-light"
	case condSnow:
		return "wx-snow"
	case condHeavySnow:
		return "wx-snow-heavy"
	case condSleet:
		return "wx-sleet"
	case condThunderstorm:
		return "wx-thunderstorm"
	case condWindy:
		return "wx-windy"
	case condHail:
		return "wx-hail"
	default:
		return "wx-unknown"
	}
}

// wxImperialLocale matches the three Fahrenheit-holdout locales (US, Liberia,
// Myanmar), used to resolve the "auto" temperature unit from the environment.
var wxImperialLocale = regexp.MustCompile(`(^|[_.@-])(US|LR|MM)([_.@-]|$)`)

// resolveUnit turns the configured unit ("auto"/"celsius"/"fahrenheit") into a
// concrete one. "auto" follows the locale environment.
func resolveUnit(unit string) string {
	switch unit {
	case "celsius", "fahrenheit":
		return unit
	default:
		env := os.Getenv("LC_MEASUREMENT")
		if env == "" {
			env = os.Getenv("LANG")
		}
		if wxImperialLocale.MatchString(env) {
			return "fahrenheit"
		}
		return "celsius"
	}
}

// wxShort renders a float the way the reference prints its raw temperature and
// wind values: the shortest decimal that round-trips the f32, no fixed places.
func wxShort(v float64) string {
	return strconv.FormatFloat(float64(float32(v)), 'f', -1, 32)
}

// fmtTemp formats a celsius value in the display unit (reference: raw f32 plus
// the unit symbol; fahrenheit = c*9/5+32).
func fmtTemp(celsius float64, unit string) string {
	if unit == "fahrenheit" {
		return wxShort(celsius*9.0/5.0+32.0) + "\u00b0F"
	}
	return wxShort(celsius) + "\u00b0C"
}

// windValue formats a km/h wind speed in the display unit (mph = kmh*0.621371).
func windValue(kmh float64, unit string) string {
	if unit == "fahrenheit" {
		return wxShort(kmh * 0.621371)
	}
	return wxShort(kmh)
}

// windUnits is the suffix that follows the wind value.
func windUnits(unit string) string {
	if unit == "fahrenheit" {
		return " mph winds"
	}
	return " kmh winds"
}

// tempInt rounds a celsius value in the display unit to a whole number, for the
// singleton's legacy numeric fields.
func tempInt(celsius float64, unit string) int {
	if unit == "fahrenheit" {
		return int(math.Round(celsius*9.0/5.0 + 32.0))
	}
	return int(math.Round(celsius))
}

// fmtClock formats an ISO datetime or time as HH:MM (24h) or I:MM PM (12h).
func fmtClock(iso string, clock24 bool) string {
	t, ok := parseISOTime(iso)
	if !ok {
		return ""
	}
	if clock24 {
		return t.Format("15:04")
	}
	return t.Format("3:04 PM")
}

// fmtHour formats an ISO datetime as the hourly-column label: %H (24h) or %I %p
// (12h), matching the reference hourly item.
func fmtHour(iso string, clock24 bool) string {
	t, ok := parseISOTime(iso)
	if !ok {
		return ""
	}
	if clock24 {
		return t.Format("15")
	}
	return t.Format("03 PM")
}

// fmtWeekday formats an ISO date as the abbreviated weekday (%a).
func fmtWeekday(iso string) string {
	t, err := time.ParseInLocation("2006-01-02", iso, time.Local)
	if err != nil {
		return ""
	}
	return t.Format("Mon")
}

func parseISOTime(iso string) (time.Time, bool) {
	for _, layout := range []string{"2006-01-02T15:04", "15:04"} {
		if t, err := time.ParseInLocation(layout, iso, time.Local); err == nil {
			return t, true
		}
	}
	return time.Time{}, false
}

// --- fetch response shapes ---

type wxHourlyData struct {
	Time                     []string  `json:"time"`
	Temperature2m            []float64 `json:"temperature_2m"`
	RelativeHumidity2m       []float64 `json:"relative_humidity_2m"`
	ApparentTemperature      []float64 `json:"apparent_temperature"`
	PrecipitationProbability []float64 `json:"precipitation_probability"`
	WeatherCode              []float64 `json:"weather_code"`
	WindSpeed10m             []float64 `json:"wind_speed_10m"`
	UvIndex                  []float64 `json:"uv_index"`
	IsDay                    []float64 `json:"is_day"`
}

type wxDailyData struct {
	Time             []string  `json:"time"`
	WeatherCode      []float64 `json:"weather_code"`
	Temperature2mMax []float64 `json:"temperature_2m_max"`
	Temperature2mMin []float64 `json:"temperature_2m_min"`
	Sunrise          []string  `json:"sunrise"`
	Sunset           []string  `json:"sunset"`
	UvIndexMax       []float64 `json:"uv_index_max"`
}

type wxForecastResponse struct {
	Hourly wxHourlyData `json:"hourly"`
	Daily  wxDailyData  `json:"daily"`
}

// wxLocation is a resolved place: coordinates plus the display name parts.
type wxLocation struct {
	city, region, country string
	lat, lon              float64
}

// locationLine builds the reference location string: "{city}, {region or
// country}", or "{lat}, {lon}" when the city is empty.
func (l wxLocation) locationLine() string {
	if l.city == "" {
		return wxShort(l.lat) + ", " + wxShort(l.lon)
	}
	tail := l.region
	if tail == "" {
		tail = l.country
	}
	if tail == "" {
		return l.city
	}
	return l.city + ", " + tail
}

// --- published state shapes ---

type wxCurrent struct {
	Icon        string `json:"icon"`
	Code        int    `json:"code"`
	IsDay       bool   `json:"isDay"`
	Temperature string `json:"temperature"`
	FeelsLike   string `json:"feelsLike"`
	Humidity    int    `json:"humidity"`
	UvIndex     int    `json:"uvIndex"`
	Wind        string `json:"wind"`
	WindUnits   string `json:"windUnits"`
	Sunrise     string `json:"sunrise"`
	Sunset      string `json:"sunset"`
	// Legacy numeric views for the sidebar consumers.
	Temp      int `json:"temp"`
	Feels     int `json:"feels"`
	WindValue int `json:"windValue"`
}

type wxHour struct {
	Time        string `json:"time"`
	Hour        string `json:"hour"`
	Icon        string `json:"icon"`
	Code        int    `json:"code"`
	Temp        int    `json:"temp"`
	Temperature string `json:"temperature"`
	Uv          string `json:"uv"`
	Precip      int    `json:"precip"`
}

type wxDay struct {
	Weekday string `json:"weekday"`
	Day     string `json:"day"`
	Icon    string `json:"icon"`
	Code    int    `json:"code"`
	Hi      int    `json:"hi"`
	Lo      int    `json:"lo"`
	High    string `json:"high"`
	Low     string `json:"low"`
}

type wxFrame struct {
	Status    string     `json:"status"`
	ErrorKind string     `json:"errorKind"`
	Error     string     `json:"error"`
	Location  string     `json:"location"`
	City      string     `json:"city"`
	HasData   bool       `json:"hasData"`
	Current   *wxCurrent `json:"current"`
	Hourly    []wxHour   `json:"hourly"`
	Daily     []wxDay    `json:"daily"`
}

// wxConfig is the location and display configuration QML pushes in.
type wxConfig struct {
	query   string
	lat     float64
	lon     float64
	unit    string
	clock24 bool
}

// wxState holds the weather poller: its topic, its live config, and a wake
// channel that configure and retry use to force a fresh fetch.
type wxState struct {
	topic  *stateTopic
	client *http.Client

	mu  sync.Mutex
	cfg wxConfig
	loc *wxLocation // last resolved place, reused while the query is unchanged

	wake  chan struct{}
	quit  chan struct{}
	first bool
}

// hasSubscribers reports whether any client is subscribed to the topic, so a
// poll tick can be skipped when the menu is closed (reference behavior).
func (t *stateTopic) hasSubscribers() bool {
	t.mu.Lock()
	defer t.mu.Unlock()
	return len(t.subs) > 0
}

// startWeather registers the weather topic and its control calls, publishes the
// initial loading frame, and starts the poll loop.
func (d *daemon) startWeather() {
	s := &wxState{
		topic:  d.registerTopic("weather"),
		client: &http.Client{Timeout: wxHTTPTimeout},
		cfg:    wxConfig{unit: "auto", clock24: true},
		wake:   make(chan struct{}, 1),
		quit:   d.quit,
	}
	s.publishFrame(wxFrame{Status: "loading", Hourly: []wxHour{}, Daily: []wxDay{}})

	d.registerCall("weather.configure", func(raw json.RawMessage) (any, error) {
		var a struct {
			Location string   `json:"location"`
			Lat      *float64 `json:"lat"`
			Lon      *float64 `json:"lon"`
			Unit     string   `json:"unit"`
			Clock24  *bool    `json:"clock24"`
		}
		if err := json.Unmarshal(raw, &a); err != nil {
			return nil, err
		}
		next := wxConfig{query: strings.TrimSpace(a.Location), unit: a.Unit, clock24: true}
		if a.Lat != nil {
			next.lat = *a.Lat
		}
		if a.Lon != nil {
			next.lon = *a.Lon
		}
		if next.unit == "" {
			next.unit = "auto"
		}
		if a.Clock24 != nil {
			next.clock24 = *a.Clock24
		}
		s.configure(next)
		return map[string]any{"ok": true}, nil
	})

	d.registerCall("weather.retry", func(json.RawMessage) (any, error) {
		s.signalWake()
		return map[string]any{"ok": true}, nil
	})

	go s.run()
}

// configure swaps the live config. A changed location query drops the cached
// resolved place so the next fetch re-geocodes; any change kicks a fresh fetch.
func (s *wxState) configure(next wxConfig) {
	s.mu.Lock()
	changed := next != s.cfg
	locChanged := next.query != s.cfg.query || next.lat != s.cfg.lat || next.lon != s.cfg.lon
	s.cfg = next
	if locChanged {
		s.loc = nil
	}
	s.mu.Unlock()
	if changed {
		s.signalWake()
	}
}

func (s *wxState) signalWake() {
	select {
	case s.wake <- struct{}{}:
	default:
	}
}

// run is the poll loop: it fetches immediately, then every 15 minutes, skipping
// a tick when nothing is subscribed (after the first fetch). configure and retry
// wake it out of band.
func (s *wxState) run() {
	ticker := time.NewTicker(wxPollInterval)
	defer ticker.Stop()
	s.fetchOnce()
	for {
		select {
		case <-s.quit:
			return
		case <-s.wake:
			s.fetchOnce()
		case <-ticker.C:
			if !s.topic.hasSubscribers() {
				continue
			}
			s.fetchOnce()
		}
	}
}

// fetchOnce resolves the location if needed and fetches the forecast with the
// retry ladder, publishing the loaded frame or an error frame.
func (s *wxState) fetchOnce() {
	s.mu.Lock()
	cfg := s.cfg
	loc := s.loc
	s.mu.Unlock()

	unit := resolveUnit(cfg.unit)

	if loc == nil {
		resolved, kind, err := s.resolveLocation(cfg)
		if err != nil {
			s.publishError(kind)
			return
		}
		loc = resolved
		s.mu.Lock()
		s.loc = loc
		s.mu.Unlock()
	}

	for attempt := 1; attempt <= wxMaxRetries; attempt++ {
		data, kind, err := s.fetchForecast(loc.lat, loc.lon)
		if err == nil {
			s.publishFrame(buildFrame(data, *loc, unit, cfg.clock24))
			return
		}
		if !wxRetryable(kind) || attempt == wxMaxRetries {
			s.publishError(kind)
			return
		}
		delay := wxRetryBase * time.Duration(1<<(attempt-1))
		if kind == wxErrRateLimited {
			delay = wxRateWait
		}
		select {
		case <-s.quit:
			return
		case <-s.wake:
			// A configure/retry arrived mid-backoff: restart the fetch cycle.
			s.signalWake()
			return
		case <-time.After(delay):
		}
	}
}

func wxRetryable(kind string) bool {
	return kind == wxErrNetwork || kind == wxErrRateLimited
}

// resolveLocation turns the config into concrete coordinates. An explicit city
// query geocodes; explicit coordinates are used directly; an empty query falls
// back to a keyless IP lookup (the Ryoku divergence).
func (s *wxState) resolveLocation(cfg wxConfig) (*wxLocation, string, error) {
	if cfg.query != "" {
		return s.geocode(cfg.query)
	}
	if cfg.lat != 0 || cfg.lon != 0 {
		return &wxLocation{lat: cfg.lat, lon: cfg.lon}, "", nil
	}
	return s.ipLocate()
}

func (s *wxState) geocode(name string) (*wxLocation, string, error) {
	q := url.Values{}
	q.Set("name", name)
	q.Set("count", "1")
	var resp struct {
		Results []struct {
			Latitude  float64 `json:"latitude"`
			Longitude float64 `json:"longitude"`
			Name      string  `json:"name"`
			Admin1    string  `json:"admin1"`
			Country   string  `json:"country"`
		} `json:"results"`
	}
	if kind, err := s.getJSON(wxGeocodingURL+"?"+q.Encode(), &resp); err != nil {
		return nil, kind, err
	}
	if len(resp.Results) == 0 {
		return nil, wxErrLocationNotFound, fmt.Errorf("location not found: %s", name)
	}
	r := resp.Results[0]
	return &wxLocation{city: r.Name, region: r.Admin1, country: r.Country, lat: r.Latitude, lon: r.Longitude}, "", nil
}

func (s *wxState) ipLocate() (*wxLocation, string, error) {
	var resp struct {
		Status     string  `json:"status"`
		City       string  `json:"city"`
		RegionName string  `json:"regionName"`
		Country    string  `json:"country"`
		Lat        float64 `json:"lat"`
		Lon        float64 `json:"lon"`
	}
	if kind, err := s.getJSON(wxIPURL, &resp); err != nil {
		return nil, kind, err
	}
	if resp.Status != "" && resp.Status != "success" {
		return nil, wxErrLocationNotFound, fmt.Errorf("ip lookup failed")
	}
	return &wxLocation{city: resp.City, region: resp.RegionName, country: resp.Country, lat: resp.Lat, lon: resp.Lon}, "", nil
}

// fetchForecast requests the forecast for a coordinate, always in celsius/kmh.
func (s *wxState) fetchForecast(lat, lon float64) (*wxForecastResponse, string, error) {
	q := url.Values{}
	q.Set("latitude", strconv.FormatFloat(lat, 'f', -1, 64))
	q.Set("longitude", strconv.FormatFloat(lon, 'f', -1, 64))
	q.Set("hourly", wxHourlyParams)
	q.Set("daily", wxDailyParams)
	q.Set("temperature_unit", "celsius")
	q.Set("wind_speed_unit", "kmh")
	q.Set("timezone", "auto")
	q.Set("forecast_days", "7")
	var resp wxForecastResponse
	if kind, err := s.getJSON(wxForecastURL+"?"+q.Encode(), &resp); err != nil {
		return nil, kind, err
	}
	return &resp, "", nil
}

// getJSON performs a GET and decodes JSON, mapping transport and status failures
// to the reference error kinds.
func (s *wxState) getJSON(rawURL string, out any) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), wxHTTPTimeout)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, rawURL, nil)
	if err != nil {
		return wxErrOther, err
	}
	resp, err := s.client.Do(req)
	if err != nil {
		return wxErrNetwork, err
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusTooManyRequests {
		return wxErrRateLimited, fmt.Errorf("rate limited")
	}
	if resp.StatusCode >= 500 {
		return wxErrOther, fmt.Errorf("provider status %d", resp.StatusCode)
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return wxErrOther, fmt.Errorf("provider status %d", resp.StatusCode)
	}
	if err := json.NewDecoder(resp.Body).Decode(out); err != nil {
		return wxErrOther, err
	}
	return "", nil
}

// currentHourIndex finds the entry for the current hour: the last entry whose
// time is not in the future (reference find_current_hour_index).
func currentHourIndex(times []string) int {
	now := time.Now()
	for i, t := range times {
		if parsed, ok := parseISOTime(t); ok && parsed.After(now) {
			if i == 0 {
				return 0
			}
			return i - 1
		}
	}
	return 0
}

func at(arr []float64, i int) float64 {
	if i >= 0 && i < len(arr) {
		return arr[i]
	}
	return 0
}

func clampInt(v float64, lo, hi int) int {
	n := int(math.Round(v))
	if n < lo {
		return lo
	}
	if n > hi {
		return hi
	}
	return n
}

// buildFrame turns a forecast response into the published frame, applying the
// display unit and clock format. Current conditions come from the current hour;
// hourly keeps 24 entries from that hour; daily keeps 7; astronomy is daily[0].
func buildFrame(data *wxForecastResponse, loc wxLocation, unit string, clock24 bool) wxFrame {
	h := data.Hourly
	idx := currentHourIndex(h.Time)

	frame := wxFrame{
		Status:   "loaded",
		Location: loc.locationLine(),
		City:     loc.city,
		HasData:  true,
		Hourly:   []wxHour{},
		Daily:    []wxDay{},
	}

	var sunrise, sunset string
	if len(data.Daily.Sunrise) > 0 {
		sunrise = fmtClock(data.Daily.Sunrise[0], clock24)
	}
	if len(data.Daily.Sunset) > 0 {
		sunset = fmtClock(data.Daily.Sunset[0], clock24)
	}

	if idx < len(h.Time) && len(h.Time) > 0 {
		code := int(at(h.WeatherCode, idx))
		isDay := at(h.IsDay, idx) > 0.5
		cond := wmoCondition(code)
		celsius := at(h.Temperature2m, idx)
		feels := at(h.ApparentTemperature, idx)
		windKmh := at(h.WindSpeed10m, idx)
		frame.Current = &wxCurrent{
			Icon:        weatherIcon(cond, isDay),
			Code:        code,
			IsDay:       isDay,
			Temperature: fmtTemp(celsius, unit),
			FeelsLike:   fmtTemp(feels, unit),
			Humidity:    clampInt(at(h.RelativeHumidity2m, idx), 0, 100),
			UvIndex:     clampInt(at(h.UvIndex, idx), 0, 15),
			Wind:        windValue(windKmh, unit),
			WindUnits:   windUnits(unit),
			Sunrise:     sunrise,
			Sunset:      sunset,
			Temp:        tempInt(celsius, unit),
			Feels:       tempInt(feels, unit),
			WindValue:   int(math.Round(windKmhInUnit(windKmh, unit))),
		}
	}

	end := idx + 24
	if end > len(h.Time) {
		end = len(h.Time)
	}
	for i := idx; i < end; i++ {
		code := int(at(h.WeatherCode, i))
		isDay := at(h.IsDay, i) > 0.5
		cond := wmoCondition(code)
		celsius := at(h.Temperature2m, i)
		frame.Hourly = append(frame.Hourly, wxHour{
			Time:        fmtHour(h.Time[i], clock24),
			Hour:        hourField(h.Time[i]),
			Icon:        weatherIcon(cond, isDay),
			Code:        code,
			Temp:        tempInt(celsius, unit),
			Temperature: fmtTemp(celsius, unit),
			Uv:          strconv.Itoa(clampInt(at(h.UvIndex, i), 0, 15)) + " UV",
			Precip:      clampInt(at(h.PrecipitationProbability, i), 0, 100),
		})
	}

	d := data.Daily
	dend := 7
	if dend > len(d.Time) {
		dend = len(d.Time)
	}
	for i := range dend {
		code := int(at(d.WeatherCode, i))
		cond := wmoCondition(code)
		hi := at(d.Temperature2mMax, i)
		lo := at(d.Temperature2mMin, i)
		weekday := fmtWeekday(d.Time[i])
		frame.Daily = append(frame.Daily, wxDay{
			Weekday: weekday,
			Day:     weekday,
			Icon:    weatherIcon(cond, true),
			Code:    code,
			Hi:      tempInt(hi, unit),
			Lo:      tempInt(lo, unit),
			High:    fmtTemp(hi, unit),
			Low:     fmtTemp(lo, unit),
		})
	}

	return frame
}

func windKmhInUnit(kmh float64, unit string) float64 {
	if unit == "fahrenheit" {
		return kmh * 0.621371
	}
	return kmh
}

// hourField is the legacy "13" style hour label (the ISO hour digits), for the
// sidebar consumers that show a bare 24h hour.
func hourField(iso string) string {
	if len(iso) >= 13 {
		return iso[11:13]
	}
	return ""
}

func (s *wxState) publishFrame(frame wxFrame) {
	if frame.Hourly == nil {
		frame.Hourly = []wxHour{}
	}
	if frame.Daily == nil {
		frame.Daily = []wxDay{}
	}
	b, err := json.Marshal(frame)
	if err != nil {
		return
	}
	s.topic.publish(b)
}

// publishError ships an error frame, keeping the last hourly/daily so the nav
// buttons stay meaningful once data has loaded once.
func (s *wxState) publishError(kind string) {
	s.publishFrame(wxFrame{
		Status:    "error",
		ErrorKind: kind,
		Error:     weatherErrorMessage(kind),
		Hourly:    []wxHour{},
		Daily:     []wxDay{},
	})
}
