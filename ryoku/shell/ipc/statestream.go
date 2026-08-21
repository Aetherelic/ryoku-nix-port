package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"strings"
	"sync"
	"time"
)

// statestream carries typed subsystem state to QML over the same control socket
// the CLI verbs use, so a QML singleton is a view of daemon state rather than an
// independent poller. Two message families ride the socket beside the one-shot
// command lines:
//
//	subscribe <topic>            long-lived: the daemon writes a full-state JSON
//	                             frame at once, then a fresh frame on every
//	                             change. Byte-identical frames are suppressed, so
//	                             an unchanged value never wakes a binding. One
//	                             line per frame.
//	call <topic>.<method> <json> request/response: the daemon runs the method
//	                             and replies with one JSON line; the connection
//	                             stays open for further calls. An "id" in the
//	                             args is echoed back so a multiplexed client can
//	                             correlate replies.
//
// State flows one way (daemon to QML) through subscribe; intent flows the other
// (QML to daemon) through call.

// stateTopic fans a subsystem's state out to subscribers. Ordinary state
// topics coalesce unread snapshots; ordered topics retain every event and apply
// bounded backpressure instead, because a later keypress cannot replace an
// earlier one.
type topicSubscriber struct {
	frames   chan []byte
	done     chan struct{}
	stopOnce sync.Once
}

func (s *topicSubscriber) stop() {
	s.stopOnce.Do(func() { close(s.done) })
}

type stateTopic struct {
	mu      sync.Mutex
	subs    map[*topicSubscriber]struct{}
	last    []byte
	ordered bool
}

func newStateTopic() *stateTopic {
	return &stateTopic{subs: map[*topicSubscriber]struct{}{}}
}

func newEventTopic() *stateTopic {
	return &stateTopic{subs: map[*topicSubscriber]struct{}{}, ordered: true}
}

func (t *stateTopic) subscribe() *topicSubscriber {
	depth := 1
	if t.ordered {
		depth = 64
	}
	sub := &topicSubscriber{
		frames: make(chan []byte, depth),
		done:   make(chan struct{}),
	}
	t.mu.Lock()
	t.subs[sub] = struct{}{}
	if t.last != nil {
		sub.frames <- t.last
	}
	t.mu.Unlock()
	return sub
}

func (t *stateTopic) unsubscribe(sub *topicSubscriber) {
	t.mu.Lock()
	delete(t.subs, sub)
	t.mu.Unlock()
	sub.stop()
}

func (t *stateTopic) publish(frame []byte) {
	t.mu.Lock()
	if !t.ordered && bytes.Equal(frame, t.last) {
		t.mu.Unlock()
		return
	}
	t.last = frame
	subs := make([]*topicSubscriber, 0, len(t.subs))
	for sub := range t.subs {
		subs = append(subs, sub)
	}
	ordered := t.ordered
	t.mu.Unlock()

	for _, sub := range subs {
		if ordered {
			select {
			case sub.frames <- frame:
			case <-sub.done:
			}
			continue
		}
		select {
		case <-sub.done:
			continue
		case sub.frames <- frame:
		default:
			select {
			case <-sub.frames:
			default:
			}
			select {
			case sub.frames <- frame:
			case <-sub.done:
			default:
			}
		}
	}
}

func (d *daemon) installTopic(name string, topic *stateTopic) *stateTopic {
	d.topicsMu.Lock()
	defer d.topicsMu.Unlock()
	if d.topics == nil {
		d.topics = map[string]*stateTopic{}
	}
	d.topics[name] = topic
	return topic
}

// registerTopic creates a coalescing state topic. Event producers whose frames
// are individually meaningful must use registerEventTopic instead.
func (d *daemon) registerTopic(name string) *stateTopic {
	return d.installTopic(name, newStateTopic())
}

func (d *daemon) registerEventTopic(name string) *stateTopic {
	return d.installTopic(name, newEventTopic())
}

func (d *daemon) topic(name string) *stateTopic {
	d.topicsMu.Lock()
	defer d.topicsMu.Unlock()
	return d.topics[name]
}

// callFunc handles one control method. args is the raw JSON object from the call
// line (it may carry an "id" the framing echoes back and the handler ignores).
type callFunc func(args json.RawMessage) (any, error)

func (d *daemon) registerCall(method string, fn callFunc) {
	d.callsMu.Lock()
	defer d.callsMu.Unlock()
	if d.calls == nil {
		d.calls = map[string]callFunc{}
	}
	d.calls[method] = fn
}

func (d *daemon) callHandler(method string) callFunc {
	d.callsMu.Lock()
	defer d.callsMu.Unlock()
	return d.calls[method]
}

// serveSubscription streams one topic to a client until it disconnects. The
// control socket's per-command deadline is cleared first: a subscription is
// long-lived, unlike the one-shot verbs handle() otherwise bounds.
func (d *daemon) serveSubscription(conn net.Conn, cmd string) {
	name := strings.TrimSpace(strings.TrimPrefix(cmd, "subscribe"))
	t := d.topic(name)
	if t == nil {
		fmt.Fprintf(conn, "err unknown topic: %s\n", name)
		return
	}
	_ = conn.SetDeadline(time.Time{})
	sub := t.subscribe()
	defer t.unsubscribe(sub)
	done := make(chan struct{})
	go func() {
		// Any further input, or a half-close, ends the stream.
		_, _ = io.Copy(io.Discard, conn)
		close(done)
	}()
	for {
		select {
		case frame := <-sub.frames:
			if _, err := conn.Write(append(frame, '\n')); err != nil {
				return
			}
		case <-done:
			return
		case <-d.quit:
			return
		}
	}
}

// serveCalls runs control methods on one connection until it closes. first is
// the "call ..." line handle() already read.
func (d *daemon) serveCalls(conn net.Conn, r *bufio.Reader, first string) {
	_ = conn.SetDeadline(time.Time{})
	line := first
	for {
		if strings.HasPrefix(line, "call ") {
			if _, err := fmt.Fprintln(conn, d.handleCall(line)); err != nil {
				return
			}
		}
		next, err := r.ReadString('\n')
		if err != nil {
			return
		}
		line = strings.TrimSpace(next)
	}
}

func (d *daemon) handleCall(line string) string {
	rest := strings.TrimSpace(strings.TrimPrefix(line, "call "))
	method := rest
	var raw json.RawMessage
	if sp := strings.IndexByte(rest, ' '); sp >= 0 {
		method = rest[:sp]
		raw = json.RawMessage(strings.TrimSpace(rest[sp+1:]))
	}
	id := callID(raw)
	h := d.callHandler(method)
	if h == nil {
		return callReply(id, nil, fmt.Errorf("unknown method: %s", method))
	}
	result, err := h(raw)
	return callReply(id, result, err)
}

func callID(raw json.RawMessage) json.RawMessage {
	if len(raw) == 0 {
		return nil
	}
	var m map[string]json.RawMessage
	if json.Unmarshal(raw, &m) != nil {
		return nil
	}
	return m["id"]
}

func callReply(id json.RawMessage, result any, err error) string {
	reply := map[string]any{"ok": err == nil}
	if len(id) > 0 {
		reply["id"] = id
	}
	if err != nil {
		reply["error"] = err.Error()
	} else if result != nil {
		reply["result"] = result
	}
	b, e := json.Marshal(reply)
	if e != nil {
		return `{"ok":false,"error":"reply marshal failed"}`
	}
	return string(b)
}
