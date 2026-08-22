package doctor

import (
	"reflect"
	"strconv"
	"strings"
	"testing"
)

func TestConfigTimelineOff(t *testing.T) {
	cases := []struct {
		name string
		body string
		want bool
	}{
		{"number only", "SUBVOLUME=\"/\"\nTIMELINE_CREATE=\"no\"\n", true},
		{"timeline on", "TIMELINE_CREATE=\"yes\"\n", false},
		{"missing key", "SUBVOLUME=\"/\"\nNUMBER_LIMIT=\"10\"\n", false},
		{"empty", "", false},
	}
	for _, c := range cases {
		if got := configTimelineOff(c.body); got != c.want {
			t.Errorf("%s: configTimelineOff = %v, want %v", c.name, got, c.want)
		}
	}
}

func TestParseLeakedTimeline(t *testing.T) {
	csv := "number,cleanup\n" +
		"0,\n" + // base snapshot, never deletable
		"1,number\n" +
		"2,timeline\n" +
		"3,timeline\n" +
		"4,\n" +
		"5,number\n"
	got := parseLeakedTimeline(csv)
	if want := []string{"2", "3"}; !reflect.DeepEqual(got, want) {
		t.Fatalf("parseLeakedTimeline = %v, want %v", got, want)
	}
}

func TestParseLeakedTimelineSkipsNonNumbered(t *testing.T) {
	csv := "number,cleanup\nfoo,timeline\n,timeline\n7,timeline\n"
	if got := parseLeakedTimeline(csv); !reflect.DeepEqual(got, []string{"7"}) {
		t.Fatalf("got %v, want [7]", got)
	}
}

func TestChunk(t *testing.T) {
	nums := make([]string, 45)
	for i := range nums {
		nums[i] = strconv.Itoa(i + 1)
	}
	got := chunk(nums, 20)
	if len(got) != 3 {
		t.Fatalf("want 3 batches, got %d", len(got))
	}
	if len(got[0]) != 20 || len(got[1]) != 20 || len(got[2]) != 5 {
		t.Errorf("batch sizes = %d,%d,%d; want 20,20,5", len(got[0]), len(got[1]), len(got[2]))
	}
	if c := chunk(nil, 20); c != nil {
		t.Errorf("chunk(nil) = %v, want nil", c)
	}
}

func TestAddUpdatedbPrunePath(t *testing.T) {
	cases := []struct {
		name        string
		in          string
		wantChanged bool
		wantHas     string
	}{
		{"append when absent", "PRUNENAMES=\".git\"\n", true, `PRUNEPATHS="/.snapshots"`},
		{"extend existing", "PRUNEPATHS=\"/tmp /var/tmp\"\n", true, `PRUNEPATHS="/tmp /var/tmp /.snapshots"`},
		{"already present", "PRUNEPATHS=\"/tmp /.snapshots\"\n", false, ""},
	}
	for _, c := range cases {
		out, changed := addUpdatedbPrunePath(c.in, "/.snapshots")
		if changed != c.wantChanged {
			t.Errorf("%s: changed = %v, want %v", c.name, changed, c.wantChanged)
		}
		if c.wantChanged && !strings.Contains(out, c.wantHas) {
			t.Errorf("%s: output %q missing %q", c.name, out, c.wantHas)
		}
		if !c.wantChanged && out != c.in {
			t.Errorf("%s: unchanged output should equal input, got %q", c.name, out)
		}
	}
}
