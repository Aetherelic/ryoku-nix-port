package main

import (
	"encoding/binary"
	"encoding/json"
	"io"
	"os"
	"strings"
	"time"
)

// WebExtension native-messaging host (host name "ryoku_theme"). The browser
// launches it when the Ryoku extension connects; it streams the live palette
// (colors.json) as {mode,colors} on connect and on every change, until the
// browser closes stdin. Framing is the native-messaging standard: a 4-byte
// native-endian length prefix then UTF-8 JSON. See ryoku/browser.
func runBrowserHost() int {
	send := func() {
		msg := browserPalette()
		if msg == nil {
			return
		}
		b, err := json.Marshal(msg)
		if err != nil {
			return
		}
		var hdr [4]byte
		binary.LittleEndian.PutUint32(hdr[:], uint32(len(b)))
		os.Stdout.Write(hdr[:])
		os.Stdout.Write(b)
	}

	// Drain inbound frames; EOF means the browser disconnected, so exit.
	done := make(chan struct{})
	go func() {
		defer close(done)
		var hdr [4]byte
		for {
			if _, err := io.ReadFull(os.Stdin, hdr[:]); err != nil {
				return
			}
			n := binary.LittleEndian.Uint32(hdr[:])
			if n == 0 || n > 1<<20 {
				return
			}
			if _, err := io.CopyN(io.Discard, os.Stdin, int64(n)); err != nil {
				return
			}
		}
	}()

	send()
	var last time.Time
	if fi, err := os.Stat(matugenColorsPath()); err == nil {
		last = fi.ModTime()
	}
	ticker := time.NewTicker(500 * time.Millisecond)
	defer ticker.Stop()
	for {
		select {
		case <-done:
			return 0
		case <-ticker.C:
			fi, err := os.Stat(matugenColorsPath())
			if err != nil {
				continue
			}
			if fi.ModTime().After(last) {
				last = fi.ModTime()
				send()
			}
		}
	}
}

// browserPalette reads colors.json and returns the payload the extension reads:
// snake_case M3 roles plus base16, and a light/dark mode from surface luminance.
func browserPalette() map[string]any {
	b, err := os.ReadFile(matugenColorsPath())
	if err != nil {
		return nil
	}
	var raw map[string]string
	if json.Unmarshal(b, &raw) != nil {
		return nil
	}
	colors := map[string]string{}
	for _, kv := range matugenRoleKeys { // camelCase in colors.json -> snake_case
		if v := raw[kv[1]]; v != "" {
			colors[kv[0]] = v
		}
	}
	for k, v := range raw {
		if strings.HasPrefix(k, "color") || k == "background" || k == "foreground" || k == "cursor" {
			colors[k] = v
		}
	}
	if len(colors) == 0 {
		return nil
	}
	return map[string]any{"mode": staticPaletteMode(colors), "colors": colors}
}
