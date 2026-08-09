package updater

import "testing"

// Only one `ryoku update` may run at a time: a held flock refuses a second
// acquire, and releasing it frees the lock again.
func TestAcquireUpdateLockBlocksSecond(t *testing.T) {
	t.Setenv("XDG_RUNTIME_DIR", t.TempDir())

	first, busy := acquireUpdateLock()
	if busy != nil || first == nil {
		t.Fatalf("first acquire: lock=%v busy=%v", first, busy)
	}

	second, busy2 := acquireUpdateLock()
	if busy2 == nil {
		if second != nil {
			second.Close()
		}
		t.Fatal("second acquire should report an update already running")
	}

	first.Close()
	third, busy3 := acquireUpdateLock()
	if busy3 != nil || third == nil {
		t.Fatalf("acquire after release: busy=%v", busy3)
	}
	third.Close()
}

func TestHumanBytes(t *testing.T) {
	cases := []struct {
		n    uint64
		want string
	}{
		{2 << 30, "2.0 GiB"},
		{512 << 20, "512 MiB"},
		{500, "500 bytes"},
	}
	for _, c := range cases {
		if got := humanBytes(c.n); got != c.want {
			t.Errorf("humanBytes(%d) = %q, want %q", c.n, got, c.want)
		}
	}
}
