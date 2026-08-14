package doctor

import (
	"os"
	"strconv"
	"strings"
	"testing"
)

// statLine builds a /proc/<pid>/stat line with `comm` as the process name and
// `start` as field 22. Fields 3..21 are filler, which is what the parser has to
// skip to reach starttime.
func statLine(comm string, start uint64) string {
	f := []string{"4242", "(" + comm + ")", "S"}
	for i := 4; i <= 21; i++ {
		f = append(f, "0")
	}
	return strings.Join(append(f, strconv.FormatUint(start, 10), "trailing", "fields"), " ") + "\n"
}

func TestParseStartTicksReadsFieldTwentyTwo(t *testing.T) {
	got, ok := parseStartTicks(statLine("Hyprland", 60273731))
	if !ok || got != 60273731 {
		t.Fatalf("plain comm: got (%d, %v), want (60273731, true)", got, ok)
	}
}

// A process name is free-form and lands inside parentheses unescaped, so a
// whitespace split over the whole line shifts every field after it. Counting
// from the last ')' is what keeps field 22 field 22.
func TestParseStartTicksSurvivesCommWithSpacesAndParens(t *testing.T) {
	got, ok := parseStartTicks(statLine("xdg desktop (portal)", 77488096))
	if !ok || got != 77488096 {
		t.Fatalf("hostile comm: got (%d, %v), want (77488096, true)", got, ok)
	}
}

func TestParseStartTicksRejectsUnusableLines(t *testing.T) {
	for name, stat := range map[string]string{
		"no comm parens": "4242 Hyprland S 0 0\n",
		"truncated":      "4242 (Hyprland) S 0 0 0\n",
		"empty":          "",
		"unparsable":     statLine("Hyprland", 0)[:strings.LastIndex(statLine("Hyprland", 0), " 0 trailing")] + " notanumber trailing fields\n",
	} {
		if _, ok := parseStartTicks(stat); ok {
			t.Errorf("%s: parsed as usable, want rejected", name)
		}
	}
}

// The parser has to agree with the kernel's real format, not just the fixture:
// /proc/self/stat is the one stat file every test run is guaranteed to have.
func TestParseStartTicksMatchesRealProcSelf(t *testing.T) {
	b, err := os.ReadFile("/proc/self/stat")
	if err != nil {
		t.Skipf("no /proc/self/stat: %v", err)
	}
	got, ok := parseStartTicks(string(b))
	if !ok {
		t.Fatalf("could not parse /proc/self/stat: %q", b)
	}
	// Independent extraction: the kernel's own field 22, counted from the last ')'.
	want := strings.Fields(string(b)[strings.LastIndexByte(string(b), ')')+1:])[19]
	if strconv.FormatUint(got, 10) != want {
		t.Fatalf("got %d, want %s", got, want)
	}
	if got == 0 {
		t.Fatal("start time of a live process is 0")
	}
}
