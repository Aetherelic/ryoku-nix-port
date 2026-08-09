package main

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
)

// `chat` is the sidebar's multi-turn client: it drives the daemon's shared
// hermes session over /ws/chat and relays each frame as one line of JSON
// (working|delta|perm|done|error) so streamed chunks keep their newlines.
// Flags: --image <path> (repeatable), --cancel, --new.

func chatWSURL() string {
	return fmt.Sprintf("ws://127.0.0.1:%d/ws/chat", LoadConfig().Port)
}

func emitChat(frame map[string]any) {
	if b, err := json.Marshal(frame); err == nil {
		fmt.Println(string(b))
	}
}

func chatImageMime(p string) string {
	switch strings.ToLower(filepath.Ext(p)) {
	case ".jpg", ".jpeg":
		return "image/jpeg"
	case ".webp":
		return "image/webp"
	case ".gif":
		return "image/gif"
	default:
		return "image/png"
	}
}

func loadPromptImages(paths []string) []PromptImage {
	var out []PromptImage
	for _, p := range paths {
		data, mime := encodeImage(p)
		if data == "" {
			continue
		}
		out = append(out, PromptImage{Data: data, MimeType: mime})
	}
	return out
}

// encodeImage base64-encodes an image for the model, downscaling through
// ImageMagick to a sane edge (as the dashboard does) so a big screenshot or
// photo is small on the wire. If magick is missing or fails, the original
// bytes are sent.
func encodeImage(p string) (data, mime string) {
	if _, err := exec.LookPath("magick"); err == nil {
		out, err := exec.Command("magick", p, "-resize", "1568x1568>", "-strip", "-quality", "85", "jpeg:-").Output()
		if err == nil && len(out) > 0 {
			return base64.StdEncoding.EncodeToString(out), "image/jpeg"
		}
	}
	b, err := os.ReadFile(p)
	if err != nil {
		return "", ""
	}
	return base64.StdEncoding.EncodeToString(b), chatImageMime(p)
}

func emitModelsFrame(m wsOut) {
	arr := make([]map[string]any, 0, len(m.Models))
	for _, mi := range m.Models {
		arr = append(arr, map[string]any{"id": mi.ID, "name": mi.Name})
	}
	emitChat(map[string]any{"type": "models", "models": arr, "current": m.Current})
}

func cmdChat(args []string) error {
	var images, words []string
	var modelID string
	mode := "ask"
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--cancel":
			mode = "cancel"
		case "--new":
			mode = "new"
		case "--models":
			mode = "models"
		case "--set-model":
			mode = "setmodel"
			if i+1 < len(args) {
				i++
				modelID = args[i]
			}
		case "--image":
			if i+1 < len(args) {
				i++
				images = append(images, args[i])
			}
		default:
			words = append(words, args[i])
		}
	}
	q := strings.TrimSpace(strings.Join(words, " "))

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	c, _, err := websocket.Dial(ctx, chatWSURL(), nil)
	if err != nil {
		emitChat(map[string]any{"type": "error", "message": "daemon not reachable"})
		return nil
	}
	defer c.Close(websocket.StatusNormalClosure, "")
	c.SetReadLimit(4 << 20)

	switch mode {
	case "cancel":
		_ = wsjson.Write(ctx, c, wsIn{Type: "cancel"})
		time.Sleep(150 * time.Millisecond)
		return nil
	case "new":
		_ = wsjson.Write(ctx, c, wsIn{Type: "new"})
		time.Sleep(200 * time.Millisecond)
		return nil
	case "setmodel":
		if modelID != "" {
			_ = wsjson.Write(ctx, c, wsIn{Type: "set_model", ModelID: modelID})
			time.Sleep(200 * time.Millisecond)
		}
		return nil
	case "models":
		mctx, mcancel := context.WithTimeout(ctx, 4*time.Second)
		defer mcancel()
		for {
			var m wsOut
			if wsjson.Read(mctx, c, &m) != nil {
				emitChat(map[string]any{"type": "models", "models": []any{}, "current": ""})
				return nil
			}
			if m.Type == "models" {
				emitModelsFrame(m)
				return nil
			}
		}
	}

	if q == "" && len(images) == 0 {
		return nil
	}
	if err := wsjson.Write(ctx, c, wsIn{Type: "user", Text: q, Images: loadPromptImages(images)}); err != nil {
		emitChat(map[string]any{"type": "error", "message": "send failed"})
		return nil
	}

	// Skip the join greeting and the transcript replay; only the frames of the
	// turn we just started should reach the sidebar. `busy` guards against a
	// stale state:dead from before our turn (sending user revives the session).
	inReplay := false
	busy := false
	var full strings.Builder
	for {
		var m wsOut
		if err := wsjson.Read(ctx, c, &m); err != nil {
			emitChat(map[string]any{"type": "error", "message": "connection closed"})
			return nil
		}
		switch m.Type {
		case "replay_start":
			inReplay = true
			continue
		case "replay_end":
			inReplay = false
			continue
		}
		if inReplay {
			continue
		}
		switch m.Type {
		case "state":
			switch m.State {
			case "busy":
				busy = true
				emitChat(map[string]any{"type": "working", "label": "thinking"})
			case "dead":
				if busy {
					msg := m.Error
					if msg == "" {
						msg = "the agent stopped"
					}
					emitChat(map[string]any{"type": "error", "message": msg})
					return nil
				}
			}
		case "agent_thought":
			emitChat(map[string]any{"type": "working", "label": "thinking"})
		case "tool":
			if m.Title != "" && m.Status != "completed" && m.Status != "failed" {
				emitChat(map[string]any{"type": "working", "label": m.Title})
			}
		case "agent_text":
			busy = true
			full.WriteString(m.Text)
			emitChat(map[string]any{"type": "delta", "text": m.Text})
		case "permission":
			emitChat(map[string]any{"type": "perm", "title": m.Title, "requestId": m.RequestID})
		case "models":
			emitModelsFrame(m)
		case "turn_end":
			imgs := extractImages(full.String())
			if imgs == nil {
				imgs = []string{}
			}
			emitChat(map[string]any{"type": "done", "images": imgs})
			return nil
		}
	}
}
