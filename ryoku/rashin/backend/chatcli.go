package main

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
)

// chatcli.go is the Super+S sidebar's multi-turn chat client. Unlike `ask`
// (the launcher's stateless fast lane), `chat` talks to the daemon's shared
// hermes ACP session over /ws/chat, so the conversation is multi-turn and the
// answer streams as it is written. It speaks a line-oriented JSONL protocol to
// its caller (the Quickshell sidebar): one JSON frame per line, so a streamed
// chunk carries newlines safely.
//
//	{"type":"working","label":"..."}          the step the agent is on
//	{"type":"delta","text":"..."}             one streamed chunk of the answer
//	{"type":"perm","title":"...","requestId":"..."}  a permission is waiting
//	{"type":"done","images":["/abs.png"]}     the turn finished
//	{"type":"error","message":"..."}          terminal failure
//
// Flags: --image <path> (repeatable) attaches an image to the turn; --cancel
// stops the in-flight turn; --new starts a fresh session (forgets context).

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
		b, err := os.ReadFile(p)
		if err != nil {
			continue
		}
		out = append(out, PromptImage{
			Data:     base64.StdEncoding.EncodeToString(b),
			MimeType: chatImageMime(p),
		})
	}
	return out
}

func cmdChat(args []string) error {
	var images, words []string
	mode := "ask"
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--cancel":
			mode = "cancel"
		case "--new":
			mode = "new"
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
