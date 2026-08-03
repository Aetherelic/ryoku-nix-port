package main

import (
	"encoding/json"
	"fmt"
	"reflect"
	"testing"
	"time"
)

func TestParseSharePayload(t *testing.T) {
	cases := []struct {
		name string
		in   string
		want []shareProgram
	}{
		{"empty", "", []shareProgram{}},
		{
			"one window",
			"0x1[HC>]Firefox[HT>]Home page[HE>]",
			[]shareProgram{{Name: "Firefox", Windows: []shareWindow{{ID: "0x1", Title: "Home page"}}}},
		},
		{
			"grouped and sorted by program then title",
			"0x2[HC>]Firefox[HT>]Zeta[HE>][HA>]0x1[HC>]Firefox[HT>]Alpha[HE>][HA>]0x3[HC>]Alacritty[HT>]shell[HE>]",
			[]shareProgram{
				{Name: "Alacritty", Windows: []shareWindow{{ID: "0x3", Title: "shell"}}},
				{Name: "Firefox", Windows: []shareWindow{
					{ID: "0x1", Title: "Alpha"},
					{ID: "0x2", Title: "Zeta"},
				}},
			},
		},
		{
			"noise entry without field separators is dropped",
			"garbage[HA>]0x9[HC>]Kitty[HT>]term[HE>]",
			[]shareProgram{{Name: "Kitty", Windows: []shareWindow{{ID: "0x9", Title: "term"}}}},
		},
		{
			"fields are trimmed",
			"  0x5  [HC>]  Code  [HT>]  main.go  [HE>]",
			[]shareProgram{{Name: "Code", Windows: []shareWindow{{ID: "0x5", Title: "main.go"}}}},
		},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := parseSharePayload(c.in); !reflect.DeepEqual(got, c.want) {
				t.Errorf("parseSharePayload(%q) = %+v, want %+v", c.in, got, c.want)
			}
		})
	}
}

// TestScreensharePickReply drives the full request/response rendezvous and shows
// every reply form the picker can produce: a screen by output name, a region as
// output plus geometry, a window by id, and the empty cancel. shellIpc is stubbed
// so the picker "opens" without shelling out to a live Quickshell.
func TestScreensharePickReply(t *testing.T) {
	stubShellIpc(t, nil)
	d := &daemon{sup: map[string]bool{"shell": true}, activeMon: "DP-1", quit: make(chan struct{})}
	d.startScreenshare()
	pick := d.callHandler("screenshare.pick")
	reply := d.callHandler("screenshare.reply")
	if pick == nil || reply == nil {
		t.Fatal("screenshare calls not registered")
	}

	forms := []string{
		"[SELECTION]/screen:DP-1",
		"[SELECTION]/region:DP-1@100,200,640,480",
		"[SELECTION]/window:0x1",
		"",
	}
	for _, want := range forms {
		t.Run(want, func(t *testing.T) {
			ch := d.topic("screenshare").subscribe()
			defer d.topic("screenshare").unsubscribe(ch)

			done := make(chan string, 1)
			go func() {
				res, err := pick(json.RawMessage(`{"payload":"0x1[HC>]Firefox[HT>]Home[HE>]"}`))
				if err != nil {
					t.Errorf("pick: %v", err)
				}
				done <- res.(string)
			}()

			reqID := waitActive(t, ch)
			raw := json.RawMessage(fmt.Sprintf(`{"requestId":%d,"selection":%q}`, reqID, want))
			if _, err := reply(raw); err != nil {
				t.Fatalf("reply: %v", err)
			}
			select {
			case got := <-done:
				if got != want {
					t.Errorf("pick returned %q, want %q", got, want)
				}
			case <-time.After(2 * time.Second):
				t.Fatal("pick did not return after reply")
			}
		})
	}
}

// waitActive reads topic frames until one reports an in-flight request and
// returns its id.
func waitActive(t *testing.T, ch chan []byte) int64 {
	t.Helper()
	deadline := time.After(2 * time.Second)
	for {
		select {
		case frame := <-ch:
			var f struct {
				Active    bool  `json:"active"`
				RequestID int64 `json:"requestId"`
			}
			if json.Unmarshal(frame, &f) == nil && f.Active {
				return f.RequestID
			}
		case <-deadline:
			t.Fatal("no active screenshare frame published")
		}
	}
}
