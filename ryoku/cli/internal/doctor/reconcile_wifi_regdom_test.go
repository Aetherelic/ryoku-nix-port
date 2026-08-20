package doctor

import (
	"strings"
	"testing"
)

// stubWifi swaps the impure inputs the reconciler reads (radio presence, the
// effective domain, and the locale country) for fixtures, restoring the real
// ones when the test ends. It keeps every case hermetic: no real /sys, iw, or
// /etc/locale.conf is touched.
func stubWifi(t *testing.T, radio bool, domain, source string, ok bool, country string) {
	t.Helper()
	origRadio, origRegdom, origLocale := wifiRadioPresent, wifiRegdom, wifiLocaleCountry
	t.Cleanup(func() {
		wifiRadioPresent = origRadio
		wifiRegdom = origRegdom
		wifiLocaleCountry = origLocale
	})
	wifiRadioPresent = func() bool { return radio }
	wifiRegdom = func() (string, string, bool) { return domain, source, ok }
	wifiLocaleCountry = func() string { return country }
}

// A desktop with no radio must never see this reconciler at all.
func TestRegdomSkipsBoxWithNoRadio(t *testing.T) {
	stubWifi(t, false, "", "", false, "US")
	if got := reconcileWifiRegdom(true); got.status != recOK {
		t.Errorf("no radio should be ok, got %v (%s)", got.status, got.detail)
	}
}

// A box already on a real country is healthy: report ok and change nothing.
func TestRegdomHealthyDomainLeftAlone(t *testing.T) {
	stubWifi(t, true, "US", "configured", true, "")
	got := reconcileWifiRegdom(true)
	if got.status != recOK {
		t.Errorf("a set domain should be ok, got %v (%s)", got.status, got.detail)
	}
}

// Domain 00 with a country the locale reveals: check mode proposes setting it
// from that country and points the fix at the exact command.
func TestRegdomWorldDomainWouldSetFromLocale(t *testing.T) {
	stubWifi(t, true, "00", "unset", true, "DE")
	got := reconcileWifiRegdom(true)
	if got.status != recWouldFix {
		t.Fatalf("domain 00 with a locale country should be would-fix, got %v (%s)", got.status, got.detail)
	}
	if !strings.Contains(got.remedy, "ryoku-wifi-regdom set DE") {
		t.Errorf("fix should name the locale country, got %q", got.remedy)
	}
}

// Domain 00 with no country to infer: warn honestly and tell the user to pass
// their own country code, since guessing one would be wrong.
func TestRegdomWorldDomainNoLocaleWarns(t *testing.T) {
	stubWifi(t, true, "00", "unset", true, "")
	got := reconcileWifiRegdom(true)
	if got.status != recWarn {
		t.Fatalf("domain 00 with no locale country should warn, got %v (%s)", got.status, got.detail)
	}
	if !strings.Contains(got.remedy, "ryoku-wifi-regdom set <CC>") {
		t.Errorf("fix should tell the user to set a country, got %q", got.remedy)
	}
}

func TestRegdomCountryFromLocale(t *testing.T) {
	cases := map[string]string{
		"LANG=en_US.UTF-8\n":                       "US",
		"LANG=\"de_DE.UTF-8\"\nLC_TIME=en_GB.UTF-8": "DE",
		"LANG=fr_FR@euro\n":                         "FR",
		"LANG=C\n":                                  "",
		"LANG=en.UTF-8\n":                           "",
		"":                                          "",
	}
	for conf, want := range cases {
		if got := countryFromLocale(conf); got != want {
			t.Errorf("countryFromLocale(%q) = %q, want %q", conf, got, want)
		}
	}
}

func TestRegdomIwRegCountry(t *testing.T) {
	cases := map[string]string{
		"global\ncountry US: DFS-FCC\n": "US",
		"global\ncountry 00: DFS-UNSET": "00",
		"global\n(no country line)\n":   "00",
	}
	for out, want := range cases {
		if got := iwRegCountry(out); got != want {
			t.Errorf("iwRegCountry(%q) = %q, want %q", out, got, want)
		}
	}
}
