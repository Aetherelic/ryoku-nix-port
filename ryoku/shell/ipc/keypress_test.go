package main

import (
	"context"
	"encoding/binary"
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"testing"
	"time"
)

// Losing any of these four capabilities makes a keyboard look like a button
// panel; accepting a mouse bitmap would open unrelated input devices.
func TestIsKeyboardCapabilities(t *testing.T) {
	cases := []struct {
		name string
		raw  string
		want bool
	}{
		{"keyboard", "200100050000000", true},
		{"mouse or button panel", "1", false},
		{"missing space", "100050000000", false},
		{"malformed", "not-hex", false},
		{"empty", "", false},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := isKeyboardCapabilities(c.raw); got != c.want {
				t.Fatalf("isKeyboardCapabilities(%q) = %v, want %v", c.raw, got, c.want)
			}
		})
	}
}

// A wrong key map either lies to viewers or leaks ordinary typing through the
// Shortcuts-only filter, so labels and printable classification are one contract.
func TestKeyForCode(t *testing.T) {
	cases := []struct {
		code      uint16
		label     string
		printable bool
		ok        bool
	}{
		{30, "A", true, true},
		{2, "1", true, true},
		{12, "-", true, true},
		{57, "Space", true, true},
		{103, "↑", false, true},
		{125, "Super", false, true},
		{248, "Mic Mute", false, true},
		{600, "", false, false},
	}
	for _, c := range cases {
		got, ok := keyForCode(c.code)
		if ok != c.ok || got.label != c.label || got.printable != c.printable {
			t.Fatalf("keyForCode(%d) = (%q, printable=%v, ok=%v), want (%q, printable=%v, ok=%v)",
				c.code, got.label, got.printable, ok, c.label, c.printable, c.ok)
		}
	}
}

// Chords must use one stable modifier order regardless of physical press order.
func TestKeyComposerBuildsChord(t *testing.T) {
	var c keyComposer
	if got := c.handle(42, 1, "all"); got != nil { // Shift down
		t.Fatalf("Shift press emitted %#v, want no chord until a base key", got)
	}
	if got := c.handle(29, 1, "all"); got != nil { // Ctrl down
		t.Fatalf("Ctrl press emitted %#v, want no chord until a base key", got)
	}
	got := c.handle(19, 1, "all") // R down
	if got == nil || !reflect.DeepEqual(got.keys, []string{"Ctrl", "Shift", "R"}) || got.repeat {
		t.Fatalf("Ctrl+Shift+R = %#v, want keys [Ctrl Shift R], repeat false", got)
	}
}

func TestKeyComposerTracksHoldUntilRelease(t *testing.T) {
	var c keyComposer
	pressed := c.handle(30, 1, "all")
	if pressed == nil || pressed.state != "pressed" || !reflect.DeepEqual(pressed.keys, []string{"A"}) {
		t.Fatalf("A press = %#v, want held A", pressed)
	}
	repeated := c.handle(30, 2, "all")
	if repeated == nil || repeated.state != "pressed" || !repeated.repeat ||
		!reflect.DeepEqual(repeated.keys, []string{"A"}) {
		t.Fatalf("A repeat = %#v, want held repeated A", repeated)
	}
	released := c.handle(30, 0, "all")
	if released == nil || released.state != "released" || released.repeat ||
		!reflect.DeepEqual(released.keys, []string{"A"}) {
		t.Fatalf("A release = %#v, want released A", released)
	}
	if got := c.handle(30, 0, "all"); got != nil {
		t.Fatalf("duplicate A release emitted %#v", got)
	}
}

func TestKeyComposerReleaseKeepsPressedChord(t *testing.T) {
	var c keyComposer
	c.handle(42, 1, "all") // Shift down.
	pressed := c.handle(2, 1, "all")
	c.handle(42, 0, "all") // Shift up before the base key.
	released := c.handle(2, 0, "all")
	want := []string{"Shift", "!"}
	if pressed == nil || released == nil ||
		!reflect.DeepEqual(pressed.keys, want) || !reflect.DeepEqual(released.keys, want) ||
		pressed.state != "pressed" || released.state != "released" {
		t.Fatalf("Shift+1 lifecycle = (%#v, %#v), want pressed/released %v", pressed, released, want)
	}
}

func TestKeyComposerReleasesHeldKeysWhenSourceLeaves(t *testing.T) {
	var c keyComposer
	c.handleSource(7, 30, 1, "all")
	released := c.removeSource(7)
	if len(released) != 1 || released[0].state != "released" ||
		!reflect.DeepEqual(released[0].keys, []string{"A"}) {
		t.Fatalf("source removal released %#v, want released A", released)
	}
}

func TestKeyComposerUsesRyokuModifierOrder(t *testing.T) {
	var c keyComposer
	c.handle(125, 1, "shortcuts") // Super down.
	c.handle(42, 1, "shortcuts")  // Shift down.

	got := c.handle(19, 1, "shortcuts")
	if got == nil || !reflect.DeepEqual(got.keys, []string{"Super", "Shift", "R"}) {
		t.Fatalf("Super+Shift+R = %#v, want keys [Super Shift R]", got)
	}
}

func TestKeyComposerUsesShiftedNumberLabels(t *testing.T) {
	cases := []struct {
		code uint16
		want string
	}{
		{2, "!"},
		{3, "@"},
		{4, "#"},
		{5, "$"},
		{6, "%"},
		{7, "^"},
		{8, "&"},
		{9, "*"},
		{10, "("},
		{11, ")"},
	}
	for _, tc := range cases {
		var c keyComposer
		c.handle(42, 1, "all") // Shift down.
		got := c.handle(tc.code, 1, "all")
		want := []string{"Shift", tc.want}
		if got == nil || !reflect.DeepEqual(got.keys, want) {
			t.Errorf("Shift+keycode %d = %#v, want %v", tc.code, got, want)
		}
	}
}

func TestKeyComposerBuildsCrossDeviceChord(t *testing.T) {
	var c keyComposer
	c.handleSource(1, 29, 1, "shortcuts") // Ctrl on the first keyboard.
	got := c.handleSource(2, 46, 1, "shortcuts")
	if got == nil || !reflect.DeepEqual(got.keys, []string{"Ctrl", "C"}) {
		t.Fatalf("cross-device Ctrl+C = %#v", got)
	}

	c.removeSource(1)
	if got := c.handleSource(2, 30, 1, "shortcuts"); got != nil {
		t.Fatalf("removed keyboard left stale modifiers: %#v", got)
	}
}

func TestKeyComposerKeepsModifierUntilBothSidesRelease(t *testing.T) {
	var c keyComposer
	c.handle(29, 1, "shortcuts") // Left Ctrl down.
	c.handle(97, 1, "shortcuts") // Right Ctrl down.
	c.handle(29, 0, "shortcuts") // Left Ctrl up; Right Ctrl remains held.

	got := c.handle(30, 1, "shortcuts")
	if got == nil || !reflect.DeepEqual(got.keys, []string{"Ctrl", "A"}) {
		t.Fatalf("right Ctrl after left release = %#v, want Ctrl+A", got)
	}
	c.handle(30, 0, "shortcuts")
	if got := c.handle(97, 0, "shortcuts"); got != nil {
		t.Fatalf("used final Ctrl release emitted %#v", got)
	}
}

// Shortcuts-only must hide normal typing, including capital letters, but retain
// a real Ctrl chord and non-text navigation keys.
func TestKeyComposerShortcutFiltering(t *testing.T) {
	var c keyComposer
	c.handle(42, 1, "shortcuts") // Shift down
	if got := c.handle(30, 1, "shortcuts"); got != nil {
		t.Fatalf("Shift+A emitted %#v in shortcuts mode", got)
	}
	c.handle(30, 0, "shortcuts")
	c.handle(42, 0, "shortcuts")

	c.handle(29, 1, "shortcuts") // Ctrl down
	got := c.handle(30, 1, "shortcuts")
	if got == nil || !reflect.DeepEqual(got.keys, []string{"Ctrl", "A"}) {
		t.Fatalf("Ctrl+A = %#v, want visible Ctrl+A chord", got)
	}
	c.handle(30, 0, "shortcuts")
	c.handle(29, 0, "shortcuts")

	got = c.handle(103, 1, "shortcuts") // Up
	if got == nil || !reflect.DeepEqual(got.keys, []string{"↑"}) {
		t.Fatalf("Up = %#v, want visible navigation key", got)
	}
}

func TestKeyComposerTreatsAltGrAsTextInShortcutsMode(t *testing.T) {
	var c keyComposer
	c.handle(100, 1, "shortcuts") // Right Alt / AltGr down
	if got := c.handle(16, 1, "shortcuts"); got != nil {
		t.Fatalf("AltGr+Q emitted %#v in shortcuts mode", got)
	}
	c.handle(16, 0, "shortcuts")
	if got := c.handle(100, 0, "shortcuts"); got != nil {
		t.Fatalf("used AltGr release emitted %#v", got)
	}

	var leftAlt keyComposer
	leftAlt.handle(56, 1, "shortcuts")
	got := leftAlt.handle(16, 1, "shortcuts")
	if got == nil || !reflect.DeepEqual(got.keys, []string{"Alt", "Q"}) {
		t.Fatalf("Left Alt+Q = %#v, want visible Alt+Q shortcut", got)
	}
}

// A modifier tapped by itself still matters to a tutorial, but emitting it on
// press would briefly flash a duplicate before every chord. Emit on unused release.
func TestKeyComposerStandaloneModifier(t *testing.T) {
	var c keyComposer
	if got := c.handle(29, 1, "all"); got != nil {
		t.Fatalf("Ctrl down emitted %#v, want delayed standalone key", got)
	}
	got := c.handle(29, 0, "all")
	if got == nil || !reflect.DeepEqual(got.keys, []string{"Ctrl"}) {
		t.Fatalf("Ctrl tap = %#v, want standalone Ctrl", got)
	}
}

// Kernel repeat events should pulse/count the existing chord rather than flood
// the on-screen history; release closes the held-state lifecycle.
func TestKeyComposerMarksRepeats(t *testing.T) {
	var c keyComposer
	first := c.handle(30, 1, "all")
	repeat := c.handle(30, 2, "all")
	release := c.handle(30, 0, "all")
	if first == nil || first.repeat {
		t.Fatalf("first A press = %#v, want non-repeat", first)
	}
	if repeat == nil || !repeat.repeat || !reflect.DeepEqual(repeat.keys, []string{"A"}) {
		t.Fatalf("repeated A = %#v, want repeat A", repeat)
	}
	if release == nil || release.state != "released" || !reflect.DeepEqual(release.keys, []string{"A"}) {
		t.Fatalf("A release = %#v, want released A", release)
	}
}

func TestNormalizeKeypressMode(t *testing.T) {
	if got := normalizeKeypressMode("shortcuts"); got != "shortcuts" {
		t.Fatalf("shortcuts normalized to %q", got)
	}
	for _, raw := range []string{"", "all", "unexpected"} {
		if got := normalizeKeypressMode(raw); got != "all" {
			t.Fatalf("normalizeKeypressMode(%q) = %q, want all", raw, got)
		}
	}
}

// Device discovery must include every keyboard and exclude button-only devices
// and stale sysfs entries whose /dev node no longer exists.
func TestKeyboardEventPaths(t *testing.T) {
	sysRoot := filepath.Join(t.TempDir(), "sys", "class", "input")
	devRoot := filepath.Join(t.TempDir(), "dev", "input")
	for name, capabilities := range map[string]string{
		"event0": "200100050000000",
		"event1": "1",
		"event2": "200100050000000",
	} {
		dir := filepath.Join(sysRoot, name, "device", "capabilities")
		if err := os.MkdirAll(dir, 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(dir, "key"), []byte(capabilities), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	if err := os.MkdirAll(devRoot, 0o755); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"event0", "event1"} {
		if err := os.WriteFile(filepath.Join(devRoot, name), nil, 0o600); err != nil {
			t.Fatal(err)
		}
	}

	got, err := keyboardEventPaths(sysRoot, devRoot)
	if err != nil {
		t.Fatal(err)
	}
	want := []string{filepath.Join(devRoot, "event0")}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("keyboardEventPaths() = %v, want %v", got, want)
	}
}

// Linux input_event places a comparable kernel timestamp at bytes 0/8 and
// type/code/value at 16/18/20 on the shipped x86-64 target.
func TestDecodeLinuxInputEvent(t *testing.T) {
	raw := make([]byte, 24)
	binary.NativeEndian.PutUint64(raw[0:8], 123)
	binary.NativeEndian.PutUint64(raw[8:16], 456)
	binary.NativeEndian.PutUint16(raw[16:18], 1)
	binary.NativeEndian.PutUint16(raw[18:20], 103)
	binary.NativeEndian.PutUint32(raw[20:24], 2)
	got, ok := decodeLinuxInputEvent(raw)
	if !ok || got.code != 103 || got.value != 2 || got.timestampUS != 123000456 {
		t.Fatalf("decodeLinuxInputEvent() = (%#v, %v), want timestamp 123000456, code 103, value 2", got, ok)
	}
	binary.NativeEndian.PutUint16(raw[16:18], 0)
	if _, ok := decodeLinuxInputEvent(raw); ok {
		t.Fatal("EV_SYN decoded as a key event")
	}
	if _, ok := decodeLinuxInputEvent(raw[:23]); ok {
		t.Fatal("short input_event decoded successfully")
	}
}

func TestOrderedKeyEventsComposeCrossDeviceShortcutByKernelTime(t *testing.T) {
	var pending []keyDeviceMessage
	pending = insertOrderedKeyMessage(pending, keyDeviceMessage{
		readerID: 2, hasEvent: true, timestampUS: 200,
		event: linuxKeyEvent{code: 46, value: 1, timestampUS: 200}, // C
	})
	pending = insertOrderedKeyMessage(pending, keyDeviceMessage{
		readerID: 1, hasEvent: true, timestampUS: 100,
		event: linuxKeyEvent{code: 29, value: 1, timestampUS: 100}, // Ctrl
	})

	var composer keyComposer
	var got *keypressEvent
	for _, message := range pending {
		if event := composer.handleSource(
			message.readerID, message.event.code, message.event.value, "shortcuts"); event != nil {
			got = event
		}
	}
	if got == nil || !reflect.DeepEqual(got.keys, []string{"Ctrl", "C"}) {
		t.Fatalf("reversed channel delivery composed %#v, want Ctrl+C in kernel order", got)
	}
}

func TestKeyEventBatchDrainsQueuedEarlierEventBeforeControl(t *testing.T) {
	active := map[string]keyDeviceReader{
		"modifier": {id: 1},
		"key":      {id: 2},
		"other":    {id: 3},
	}
	var pending []keyDeviceMessage
	pending = appendKeyDeviceBatch(pending, keyDeviceMessage{
		path: "key", readerID: 2, hasEvent: true, timestampUS: 200,
		event: linuxKeyEvent{code: 46, value: 1, timestampUS: 200}, // C
	})
	pending = appendKeyDeviceBatch(pending, keyDeviceMessage{
		path: "other", readerID: 3, timestampUS: 250, // disappearance
	})

	messages := make(chan keyDeviceMessage, 1)
	messages <- keyDeviceMessage{
		path: "modifier", readerID: 1, hasEvent: true, timestampUS: 100,
		event: linuxKeyEvent{code: 29, value: 1, timestampUS: 100}, // Ctrl
	}
	pending = drainKeyDeviceBatch(messages, active, pending)

	if len(pending) != 3 || pending[0].timestampUS != 100 ||
		pending[1].timestampUS != 200 || pending[2].timestampUS != 250 {
		t.Fatalf("drained batch = %#v, want Ctrl, C, then control", pending)
	}
}

func TestKeyEventBatchAppliesDisappearanceBeforeLaterEvent(t *testing.T) {
	pending := []keyDeviceMessage{
		{
			path: "key", readerID: 2, hasEvent: true, timestampUS: 100,
			event: linuxKeyEvent{code: 32, value: 1, timestampUS: 100}, // D
		},
		{path: "modifier", readerID: 1, timestampUS: 150}, // disappearance
		{
			path: "key", readerID: 2, hasEvent: true, timestampUS: 200,
			event: linuxKeyEvent{code: 46, value: 1, timestampUS: 200}, // C
		},
	}

	var composer keyComposer
	composer.handleSource(1, 29, 1, "shortcuts") // Ctrl already held.
	var chords [][]string
	for _, message := range pending {
		if message.hasEvent {
			event := composer.handleSource(
				message.readerID, message.event.code, message.event.value, "shortcuts")
			if event != nil {
				chords = append(chords, event.keys)
			}
		} else {
			composer.removeSource(message.readerID)
		}
	}
	if !reflect.DeepEqual(chords, [][]string{{"Ctrl", "D"}}) {
		t.Fatalf("lifecycle-ordered chords = %v, want only Ctrl+D before disappearance", chords)
	}
}

func TestReadKeyDeviceOrdersLifecycleAndEvents(t *testing.T) {
	raw := make([]byte, linuxInputEventSize)
	binary.NativeEndian.PutUint16(raw[16:18], evKey)
	binary.NativeEndian.PutUint16(raw[18:20], 30)
	binary.NativeEndian.PutUint32(raw[20:24], 1)
	path := filepath.Join(t.TempDir(), "event0")
	if err := os.WriteFile(path, raw, 0o600); err != nil {
		t.Fatal(err)
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	messages := make(chan keyDeviceMessage, 3)
	go readKeyDevice(ctx, ctx, path, 7, messages)

	want := []struct {
		opened   bool
		hasEvent bool
	}{
		{opened: true},
		{hasEvent: true},
		{},
	}
	for i, expected := range want {
		select {
		case message := <-messages:
			if message.path != path || message.readerID != 7 ||
				message.opened != expected.opened || message.hasEvent != expected.hasEvent {
				t.Fatalf("message %d = %#v", i, message)
			}
			if message.hasEvent && (message.event.code != 30 || message.event.value != 1) {
				t.Fatalf("event message = %#v", message.event)
			}
		case <-time.After(time.Second):
			t.Fatalf("timed out waiting for device message %d", i)
		}
	}
}

func TestKeyDeviceRemovalStatusKeepsHealthyReaderReady(t *testing.T) {
	frame := keyDeviceRemovalFrame(os.ErrNotExist, 1)
	if frame.Status != "ready" || frame.Error != "" {
		t.Fatalf("one failed reader with another active = %#v, want ready", frame)
	}

	frame = keyDeviceRemovalFrame(os.ErrNotExist, 0)
	if frame.Status != "error" || frame.Error == "" {
		t.Fatalf("last failed reader = %#v, want error", frame)
	}

	frame = keyDeviceRemovalFrame(nil, 0)
	if frame.Status != "error" || frame.Error == "" {
		t.Fatalf("graceful last-reader removal = %#v, want unavailable", frame)
	}

	readers := map[string]keyDeviceReader{
		"removed":  {opened: true, removing: true},
		"removing": {opened: true, removing: true},
		"opening":  {},
	}
	delete(readers, "removed")
	remaining := healthyKeyDeviceCount(readers)
	if remaining != 0 {
		t.Fatalf("healthy readers after first queued removal = %d, want 0", remaining)
	}
	frame = keyDeviceRemovalFrame(nil, remaining)
	if frame.Status != "error" {
		t.Fatalf("queued final removal resolved to %#v, want unavailable", frame)
	}
}

func TestDecodeKeypressConfigure(t *testing.T) {
	enabled, mode, err := decodeKeypressConfigure(json.RawMessage(`{"enabled":true,"mode":"shortcuts"}`))
	if err != nil || !enabled || mode != "shortcuts" {
		t.Fatalf("valid configure = (%v, %q, %v)", enabled, mode, err)
	}
	enabled, mode, err = decodeKeypressConfigure(json.RawMessage(`{"enabled":false}`))
	if err != nil || enabled || mode != "all" {
		t.Fatalf("default mode configure = (%v, %q, %v)", enabled, mode, err)
	}
	if _, _, err := decodeKeypressConfigure(json.RawMessage(`{"enabled":"yes"}`)); err == nil {
		t.Fatal("wrong enabled type accepted")
	}
}

// The stream frame is the QML boundary: it exposes viewer-ready labels and a
// timestamp for repeated identical chords, never raw device codes.
func TestMarshalKeypressEvent(t *testing.T) {
	got, err := marshalKeypressEvent(&keypressEvent{
		keys:   []string{"Super", "Shift", "R"},
		repeat: true,
		state:  "pressed",
	}, 1234, 42)
	if err != nil {
		t.Fatal(err)
	}
	var frame map[string]any
	if err := json.Unmarshal(got, &frame); err != nil {
		t.Fatal(err)
	}
	want := map[string]any{
		"status": "ready",
		"keys":   []any{"Super", "Shift", "R"},
		"repeat": true,
		"state":  "pressed",
		"time":   float64(1234),
		"serial": float64(42),
	}
	if !reflect.DeepEqual(frame, want) {
		t.Fatalf("frame = %#v, want %#v", frame, want)
	}
	if _, found := frame["code"]; found {
		t.Fatal("stream leaked raw key code")
	}
}

// This exercises the real device-reader boundary against a finite event file:
// enabling opens a discovered keyboard and disabling publishes a clean stop.
func TestKeypressManagerEnableReadDisable(t *testing.T) {
	sysRoot := filepath.Join(t.TempDir(), "sys", "class", "input")
	devRoot := filepath.Join(t.TempDir(), "dev", "input")
	capDir := filepath.Join(sysRoot, "event0", "device", "capabilities")
	if err := os.MkdirAll(capDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(devRoot, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(capDir, "key"), []byte("200100050000000"), 0o644); err != nil {
		t.Fatal(err)
	}

	raw := make([]byte, linuxInputEventSize)
	binary.NativeEndian.PutUint16(raw[16:18], evKey)
	binary.NativeEndian.PutUint16(raw[18:20], 30) // A
	binary.NativeEndian.PutUint32(raw[20:24], 1)
	if err := os.WriteFile(filepath.Join(devRoot, "event0"), raw, 0o600); err != nil {
		t.Fatal(err)
	}

	topic := newEventTopic()
	sub := topic.subscribe()
	defer topic.unsubscribe(sub)
	manager := newKeypressManager(topic, sysRoot, devRoot, filepath.Join(t.TempDir(), "keypresses.json"))
	manager.configure(true, "all")
	defer manager.configure(false, "all")

	deadline := time.After(time.Second)
	for {
		select {
		case raw := <-sub.frames:
			var frame keypressFrame
			if err := json.Unmarshal(raw, &frame); err != nil {
				t.Fatal(err)
			}
			if reflect.DeepEqual(frame.Keys, []string{"A"}) && frame.State == "pressed" {
				if frame.Status != "ready" || frame.Time == 0 {
					t.Fatalf("A frame = %#v, want ready with timestamp", frame)
				}
				manager.configure(false, "all")
				stopDeadline := time.After(time.Second)
				for {
					select {
					case stopped := <-sub.frames:
						if err := json.Unmarshal(stopped, &frame); err != nil {
							t.Fatal(err)
						}
						if frame.Status == "disabled" {
							if len(frame.Keys) != 0 {
								t.Fatalf("disabled frame = %#v", frame)
							}
							return
						}
					case <-stopDeadline:
						t.Fatal("disable did not publish a stopped frame")
					}
				}
			}
		case <-deadline:
			t.Fatal("manager did not publish the keyboard event")
		}
	}
}

func TestStartKeypressRegistersIPC(t *testing.T) {
	t.Setenv("XDG_CONFIG_HOME", t.TempDir())
	d := &daemon{}
	d.startKeypress()
	if d.keypress == nil || d.topic("keypress") == nil {
		t.Fatal("startKeypress did not create manager and stream topic")
	}
	handler := d.callHandler("keypress.configure")
	if handler == nil {
		t.Fatal("startKeypress did not register keypress.configure")
	}
	result, err := handler(json.RawMessage(`{"enabled":false,"mode":"shortcuts","id":7}`))
	if err != nil {
		t.Fatal(err)
	}
	want := map[string]any{"enabled": false, "mode": "shortcuts"}
	if !reflect.DeepEqual(result, want) {
		t.Fatalf("configure result = %#v, want %#v", result, want)
	}
	if d.keypress.currentMode() != "shortcuts" {
		t.Fatalf("manager mode = %q, want shortcuts", d.keypress.currentMode())
	}
	settingsHandler := d.callHandler("keypress.settings")
	if settingsHandler == nil {
		t.Fatal("startKeypress did not register keypress.settings")
	}
	saved, err := settingsHandler(json.RawMessage(`{"theme":"light"}`))
	if err != nil {
		t.Fatal(err)
	}
	if got := saved.(keypressSettings).Theme; got != "light" {
		t.Fatalf("saved theme = %q, want light", got)
	}
}

// A Hub theme edit must merge into the latest daemon-owned document; replacing
// the object would silently throw away the placement written by desktop drag.
func TestKeypressSettingsPatchPreservesPlacement(t *testing.T) {
	path := filepath.Join(t.TempDir(), "ryoku", "keypresses.json")
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	initial := `{"theme":"dark","mode":"all","px":-320,"py":42,"monitor":"DP-1"}`
	if err := os.WriteFile(path, []byte(initial), 0o600); err != nil {
		t.Fatal(err)
	}

	manager := newKeypressManager(newStateTopic(), "", "", path)
	if _, err := manager.patchSettings(json.RawMessage(`{"theme":"light"}`)); err != nil {
		t.Fatal(err)
	}
	body, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var got map[string]any
	if err := json.Unmarshal(body, &got); err != nil {
		t.Fatal(err)
	}
	want := map[string]any{
		"theme":   "light",
		"mode":    "all",
		"px":      float64(-320),
		"py":      float64(42),
		"monitor": "DP-1",
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("patched settings = %#v, want %#v", got, want)
	}

	before := string(body)
	if _, err := manager.patchSettings(json.RawMessage(`{"theme":"neon"}`)); err == nil {
		t.Fatal("invalid theme accepted")
	}
	after, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if string(after) != before {
		t.Fatal("invalid patch changed the settings file")
	}
}

func TestKeypressSettingsPatchUpdatesLiveMode(t *testing.T) {
	manager := newKeypressManager(newStateTopic(), "", "", filepath.Join(t.TempDir(), "keypresses.json"))
	if manager.currentMode() != "all" {
		t.Fatalf("default mode = %q, want all", manager.currentMode())
	}
	if _, err := manager.patchSettings(json.RawMessage(`{"mode":"shortcuts"}`)); err != nil {
		t.Fatal(err)
	}
	if manager.currentMode() != "shortcuts" {
		t.Fatalf("patched mode = %q, want shortcuts", manager.currentMode())
	}
}

func TestKeypressPlacementPatchPreservesPreviewMode(t *testing.T) {
	manager := newKeypressManager(newStateTopic(), "", "", filepath.Join(t.TempDir(), "keypresses.json"))
	manager.mode = "shortcuts"

	saved, err := manager.patchSettings(json.RawMessage(`{"px":320,"py":240,"monitor":"eDP-1"}`))
	if err != nil {
		t.Fatal(err)
	}
	if saved.Mode != "all" {
		t.Fatalf("persisted mode = %q, want all", saved.Mode)
	}
	if manager.currentMode() != "shortcuts" {
		t.Fatalf("preview mode = %q, want shortcuts", manager.currentMode())
	}
}
