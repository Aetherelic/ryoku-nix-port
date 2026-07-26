// ryoku-share is the desktop portal screen-share picker helper. xdg-desktop-
// portal-hyprland runs it as the screencopy custom_picker_binary with the
// candidate window list in XDPH_WINDOW_SHARING_LIST, reads its stdout, and
// shares whatever it names. The helper is a thin client: it hands the list to
// the shell daemon over the control socket, the daemon opens the picker and
// blocks until the user chooses, and the helper prints the daemon's reply
// verbatim. The payload separators and the reply strings are the portal's own
// contract, reproduced unchanged in the daemon; this helper only forwards them
// (contracts 09 and 15).
package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"time"
)

// sockName mirrors the daemon's control socket (ryoku-shell.sock under
// XDG_RUNTIME_DIR). It is the one transport coordinate this client shares with
// the daemon; the request framing beyond it is the ordinary call protocol.
const sockName = "ryoku-shell.sock"

func sockPath() string {
	dir := os.Getenv("XDG_RUNTIME_DIR")
	if dir == "" {
		dir = "/tmp"
	}
	return filepath.Join(dir, sockName)
}

func main() {
	sel, err := pick(os.Getenv("XDPH_WINDOW_SHARING_LIST"))
	if err != nil {
		fmt.Fprintln(os.Stderr, "ryoku-share:", err)
		os.Exit(1)
	}
	// One line to stdout: the selection, or an empty line the portal reads as a
	// cancel.
	fmt.Println(sel)
}

// pick sends the candidate list to the daemon and returns the picker's reply.
// The read has no deadline: the picker blocks until the user selects or cancels,
// and the daemon's own safety timeout guarantees a reply eventually arrives.
func pick(payload string) (string, error) {
	conn, err := net.DialTimeout("unix", sockPath(), 2*time.Second)
	if err != nil {
		return "", fmt.Errorf("shell daemon not reachable at %s (is `ryoku-shell daemon` running?)", sockPath())
	}
	defer conn.Close()

	req, err := json.Marshal(map[string]string{"payload": payload})
	if err != nil {
		return "", err
	}
	if _, err := fmt.Fprintf(conn, "call screenshare.pick %s\n", req); err != nil {
		return "", err
	}
	line, err := bufio.NewReader(conn).ReadString('\n')
	if err != nil {
		return "", err
	}
	return selectionFromReply(line)
}

// selectionFromReply extracts the picker's reply string from the daemon's JSON
// call response. A cancelled pick is the empty string; a daemon-side error is
// surfaced so the helper exits non-zero rather than sharing nothing silently.
func selectionFromReply(line string) (string, error) {
	var r struct {
		OK     bool   `json:"ok"`
		Result string `json:"result"`
		Error  string `json:"error"`
	}
	if err := json.Unmarshal([]byte(line), &r); err != nil {
		return "", fmt.Errorf("malformed reply from daemon")
	}
	if !r.OK {
		if r.Error == "" {
			r.Error = "screenshare request failed"
		}
		return "", fmt.Errorf("%s", r.Error)
	}
	return r.Result, nil
}
