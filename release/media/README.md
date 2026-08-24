# Release media

Images and gifs shown in the generated GitHub release notes.

A commit note points at one with a trailing `| <path>`:

    Note: New: redesigned wallpaper picker | release/media/wallpaper.gif

`bin/ryoku-release-notes` turns a repo-relative path here into a
`raw.githubusercontent.com` URL for the release ref, so the media renders in the
published release. A full `https://` URL in the note is used as-is instead.

Keep files small: a short, tightly cropped gif reads better than a long clip.
