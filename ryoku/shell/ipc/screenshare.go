package main

import (
	"encoding/json"
	"sort"
	"strings"
	"sync"
	"time"
)

// screenshare.go serves the desktop portal screen-share picker. xdg-desktop-
// portal-hyprland runs the ryoku-share helper as its screencopy custom picker;
// the helper hands the candidate window list to the daemon over the control
// socket, the daemon parses it, opens the frame's screenshare menu, and blocks
// until the picker reports the user's choice. The payload separators and the
// reply strings are the portal's own wire format and are reproduced unchanged:
// they are a third-party contract, not shell API (contracts 09 and 15).
//
// Two control calls carry the exchange:
//
//	call screenshare.pick  {"payload": <list>}      blocks -> the reply string
//	call screenshare.reply {"requestId":N,"selection":<s>}   resolves a pick
//
// and one topic streams the parsed candidates to the picker menu:
//
//	subscribe screenshare  -> {"active":bool,"requestId":N,"programs":[...]}

// Payload delimiters. xdph joins candidate windows with shareRecordSep and
// separates each entry's id / program / title with the field separators. These
// tokens are the portal's contract, so they are literal, not configurable.
const (
	shareRecordSep = "[HA>]"
	shareIDSep     = "[HC>]"
	shareTitleSep  = "[HT>]"
	shareEntrySep  = "[HE>]"
)

// shareSafety bounds the wait for a choice so a picker that never answers (no
// frame mapped, a wedged menu) cannot pin the portal helper's connection and
// its goroutine forever. The reference has no timeout; Ryoku falls back to an
// empty selection, which the portal reads as a cancel.
const shareSafety = 2 * time.Minute

// shareWindow is one candidate toplevel the portal offers to share.
type shareWindow struct {
	ID    string `json:"id"`
	Title string `json:"title"`
}

// shareProgram groups a program's shareable windows under its name.
type shareProgram struct {
	Name    string        `json:"name"`
	Windows []shareWindow `json:"windows"`
}

// screenshareState owns the picker rendezvous: the topic the menu subscribes to
// for the current candidate list, and one reply channel per in-flight portal
// request that the menu resolves.
type screenshareState struct {
	d       *daemon
	topic   *stateTopic
	mu      sync.Mutex
	pending map[int64]chan string
	nextID  int64
}

// startScreenshare registers the screenshare topic and control calls and
// publishes an inactive snapshot so a menu that subscribes before any request
// renders empty rather than stale.
func (d *daemon) startScreenshare() {
	s := &screenshareState{
		d:       d,
		topic:   d.registerTopic("screenshare"),
		pending: map[int64]chan string{},
	}
	s.publish(0, nil)
	d.registerCall("screenshare.pick", s.pick)
	d.registerCall("screenshare.reply", s.reply)
}

// pick handles one portal request. It parses the payload, opens the picker on
// the active monitor, and blocks until the menu sends a selection back, the
// safety window elapses, or the daemon quits. The returned string is the
// verbatim portal reply the helper prints.
func (s *screenshareState) pick(raw json.RawMessage) (any, error) {
	var args struct {
		Payload string `json:"payload"`
	}
	_ = json.Unmarshal(raw, &args)
	programs := parseSharePayload(args.Payload)

	s.mu.Lock()
	// At most one picker at a time (the single-open invariant): cancel any older
	// in-flight request with an empty reply before starting this one.
	for id, ch := range s.pending {
		ch <- ""
		delete(s.pending, id)
	}
	s.nextID++
	id := s.nextID
	ch := make(chan string, 1)
	s.pending[id] = ch
	s.mu.Unlock()

	s.publish(id, programs)
	// Open the picker on the active monitor. Fire-and-forget: the wait below is
	// on the user's choice, not on the surface appearing, and shellIpc retries
	// against a component that may still be starting.
	go func() {
		s.d.ensure("shell")
		shellIpc("openSurface", s.d.activeMonitor(), "screenshare")
	}()

	var sel string
	select {
	case sel = <-ch:
	case <-time.After(shareSafety):
	case <-s.d.quit:
	}

	s.mu.Lock()
	delete(s.pending, id)
	s.mu.Unlock()
	s.publish(0, nil)
	// Close the picker if it is still mapped. A selection already closed it; a
	// timeout or a shutdown did not.
	go shellIpc("closeSurface", s.d.activeMonitor(), "screenshare")
	return sel, nil
}

// reply delivers the picker's selection to the blocked pick. A reply for an
// already-resolved request (a race between a selection and the safety timeout)
// is accepted silently so the menu never sees an error it cannot avoid.
func (s *screenshareState) reply(raw json.RawMessage) (any, error) {
	var args struct {
		RequestID int64  `json:"requestId"`
		Selection string `json:"selection"`
	}
	if err := json.Unmarshal(raw, &args); err != nil {
		return nil, err
	}
	s.mu.Lock()
	ch, ok := s.pending[args.RequestID]
	if ok {
		delete(s.pending, args.RequestID)
	}
	s.mu.Unlock()
	if ok {
		ch <- args.Selection
	}
	return nil, nil
}

// publish streams the current candidate list to the picker. requestID 0 means
// no request is in flight; the menu keys its reply on the id it last saw.
func (s *screenshareState) publish(requestID int64, programs []shareProgram) {
	if programs == nil {
		programs = []shareProgram{}
	}
	frame, _ := json.Marshal(map[string]any{
		"active":    requestID != 0,
		"requestId": requestID,
		"programs":  programs,
	})
	s.topic.publish(frame)
}

// parseSharePayload turns xdph's XDPH_WINDOW_SHARING_LIST into programs grouped
// by name. Entries are shareRecordSep-separated; each is id, program and title
// split by the field separators. An entry carrying neither an id separator nor
// a title separator is noise and is dropped. Programs sort A->Z and their
// windows by title, matching the reference picker's grouping (contract 15).
func parseSharePayload(payload string) []shareProgram {
	byProgram := map[string][]shareWindow{}
	for _, entry := range strings.Split(payload, shareRecordSep) {
		entry = strings.TrimSpace(entry)
		if entry == "" {
			continue
		}
		if !strings.Contains(entry, shareIDSep) && !strings.Contains(entry, shareTitleSep) {
			continue
		}
		id, rest, _ := strings.Cut(entry, shareIDSep)
		program, titlePart, _ := strings.Cut(rest, shareTitleSep)
		title, _, _ := strings.Cut(titlePart, shareEntrySep)
		program = strings.TrimSpace(program)
		byProgram[program] = append(byProgram[program], shareWindow{
			ID:    strings.TrimSpace(id),
			Title: strings.TrimSpace(title),
		})
	}
	names := make([]string, 0, len(byProgram))
	for name := range byProgram {
		names = append(names, name)
	}
	sort.Strings(names)
	out := make([]shareProgram, 0, len(names))
	for _, name := range names {
		wins := byProgram[name]
		sort.SliceStable(wins, func(i, j int) bool { return wins[i].Title < wins[j].Title })
		out = append(out, shareProgram{Name: name, Windows: wins})
	}
	return out
}
