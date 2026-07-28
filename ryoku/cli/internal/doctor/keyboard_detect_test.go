package doctor

import "testing"

// The three sources rank: an X11 layout was set deliberately, the console keymap
// is what the installer was told, and the locale is a hint of last resort. A
// French speaker on a US board is common, so a locale must never beat a keymap.
func TestDetectLayoutSourcePrecedence(t *testing.T) {
	cases := []struct {
		name                   string
		x11, console, locale   string
		wantLayout, wantSource string
	}{
		{"x11 outranks everything", "de", "fr-latin1", "fr_FR.UTF-8", "de", "the X11 keymap"},
		{"keymap outranks locale", "", "fr-latin1", "en_US.UTF-8", "fr", "the console keymap"},
		{"locale only when nothing else", "", "", "fr_FR.UTF-8", "fr", "the system locale"},
		{"a bare keymap is its own code", "", "fr", "en_US.UTF-8", "fr", "the console keymap"},
		{"charset suffix stripped", "", "fr-latin9", "en_US.UTF-8", "fr", "the console keymap"},
		{"uk keymap is the gb layout", "", "uk", "", "gb", "the console keymap"},
		{"swiss german keymap", "", "sg", "", "ch", "the console keymap"},
		{"a second x11 layout is ignored", "fr,us", "", "", "fr", "the X11 keymap"},
		{"nothing recorded says nothing", "", "", "", "", ""},
		{"an English locale stays unmapped", "", "", "en_IE.UTF-8", "", ""},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got := detectKeyboardLayout(c.x11, c.console, c.locale)
			if got.Layout != c.wantLayout || got.Source != c.wantSource {
				t.Errorf("detect(%q,%q,%q) = %q via %q, want %q via %q",
					c.x11, c.console, c.locale, got.Layout, got.Source, c.wantLayout, c.wantSource)
			}
		})
	}
}

// A US keymap must resolve to us, not to "nothing": the caller distinguishes
// "the box says US" from "the box says nothing" only by the layout being empty.
func TestDetectUsIsAnAnswerNotSilence(t *testing.T) {
	got := detectKeyboardLayout("", "us", "en_US.UTF-8")
	if got.Layout != "us" {
		t.Errorf("us keymap = %q, want us", got.Layout)
	}
}

func TestLocaleCountry(t *testing.T) {
	cases := map[string]string{
		"fr_FR.UTF-8": "FR", "de_DE@euro": "DE", "pt_BR": "BR",
		"C": "", "": "", "en_US.UTF-8": "US",
	}
	for in, want := range cases {
		if got := localeCountry(in); got != want {
			t.Errorf("localeCountry(%q) = %q, want %q", in, got, want)
		}
	}
}

// The layout is only adopted while it is the untouched shipped default, so a
// deliberate pick (including a deliberate "us") is never overwritten later.
func TestKbLayoutRoundTripLeavesOtherKeysAlone(t *testing.T) {
	raw := `{"input":{"kbLayout":"us","kbVariant":"","numlockByDefault":false},"cursor":{"theme":"Bibata"}}`
	got, ok := hyprGetKbLayout(raw)
	if !ok || got != "us" {
		t.Fatalf("read = %q ok=%v, want us true", got, ok)
	}
	out, err := hyprSetKbLayout(raw, "fr")
	if err != nil {
		t.Fatal(err)
	}
	after, ok := hyprGetKbLayout(out)
	if !ok || after != "fr" {
		t.Errorf("after write = %q, want fr", after)
	}
	for _, keep := range []string{`"kbVariant"`, `"numlockByDefault"`, `"Bibata"`} {
		if !contains(out, keep) {
			t.Errorf("write dropped %s: %s", keep, out)
		}
	}
}

func contains(s, sub string) bool {
	return len(s) >= len(sub) && (func() bool {
		for i := 0; i+len(sub) <= len(s); i++ {
			if s[i:i+len(sub)] == sub {
				return true
			}
		}
		return false
	})()
}
