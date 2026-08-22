package updater

import (
	"reflect"
	"testing"
)

func TestParseSnapshotRows(t *testing.T) {
	out := "number,type,date,description,cleanup\n" +
		"0,single,,current,\n" + // base row, dropped
		"12,pre,2026-08-20 14:03:11,ryoku-update (from a1b2c3d),number\n" +
		"13,post,2026-08-20 14:05:22,ryoku-update,number\n"
	got := parseSnapshotRows(out)
	want := []snapshotRow{
		{number: "12", kind: "pre", date: "2026-08-20 14:03:11", description: "ryoku-update (from a1b2c3d)", cleanup: "number"},
		{number: "13", kind: "post", date: "2026-08-20 14:05:22", description: "ryoku-update", cleanup: "number"},
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("parseSnapshotRows =\n%#v\nwant\n%#v", got, want)
	}
}

func TestParseSnapshotRowsQuotedDescription(t *testing.T) {
	// snapper quotes a description that contains a comma; the CSV parse must
	// keep it one field, not split it into a bogus extra column.
	out := "number,type,date,description,cleanup\n5,single,2026-01-01 00:00:00,\"hand, made\",\n"
	got := parseSnapshotRows(out)
	if len(got) != 1 || got[0].description != "hand, made" {
		t.Fatalf("quoted description not parsed: %#v", got)
	}
}
