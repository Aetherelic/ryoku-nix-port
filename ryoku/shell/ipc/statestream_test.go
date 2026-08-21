package main

import (
	"strconv"
	"testing"
	"time"
)

func TestEventTopicPreservesBurstOrder(t *testing.T) {
	topic := newEventTopic()
	sub := topic.subscribe()
	defer topic.unsubscribe(sub)

	published := make(chan struct{})
	go func() {
		for i := 0; i < 100; i++ {
			topic.publish([]byte(strconv.Itoa(i)))
		}
		close(published)
	}()

	for want := 0; want < 100; want++ {
		select {
		case frame := <-sub.frames:
			if got := string(frame); got != strconv.Itoa(want) {
				t.Fatalf("event %d = %q", want, got)
			}
		case <-time.After(time.Second):
			t.Fatalf("timed out waiting for event %d", want)
		}
	}
	<-published
}

func TestEventTopicRetainsIdenticalEvents(t *testing.T) {
	topic := newEventTopic()
	sub := topic.subscribe()
	defer topic.unsubscribe(sub)

	topic.publish([]byte("same"))
	topic.publish([]byte("same"))
	for i := 0; i < 2; i++ {
		select {
		case frame := <-sub.frames:
			if string(frame) != "same" {
				t.Fatalf("event %d = %q", i, frame)
			}
		case <-time.After(time.Second):
			t.Fatalf("timed out waiting for duplicate event %d", i)
		}
	}
}
