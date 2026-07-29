package main

import "testing"

// The qt6ct-kde shape: an installed provider must drop the shipped name from
// the install set instead of the run dying on the conflict prompt.
func TestDropSatisfiedKeepsOnlyUnmet(t *testing.T) {
	e := &engine{}
	unmetOut := "qt6ct\nryoku-desktop\n"
	got := filterByUnmet([]string{"git", "qt6ct", "ryoku-desktop"}, unmetOut)
	want := []string{"qt6ct", "ryoku-desktop"}
	if len(got) != len(want) || got[0] != want[0] || got[1] != want[1] {
		t.Errorf("filter = %v, want %v", got, want)
	}
	_ = e
}

func TestDropSatisfiedEmptyUnmetDropsAll(t *testing.T) {
	if got := filterByUnmet([]string{"git", "curl"}, ""); len(got) != 0 {
		t.Errorf("everything satisfied should drop all, got %v", got)
	}
}
