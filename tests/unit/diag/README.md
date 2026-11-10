# Diagnostic printer fixtures

Each case adds its `.cak` file(s) to a fresh `DriverCtx`, reports the
diagnostic below, and compares what is printed with `<case>.expected`
(byte for byte, including trailing newline).

The file name in the output is the name passed to `addFile`, so add the
files by bare name with this directory as the current directory
(`setCurrentDir`), or the paths in the expected output won't match.

Spans are byte offsets, `stop` exclusive. File index is the order the files were added, starting at 0.

| Case | Files | Report | Span (file, start, stop) | Message | What it checks |
|---|---|---|---|---|---|
| mid_first_line | mid_first_line.cak | error | 0, 4, 5 | `test message` | first line, middle |
| middle_line | middle_line.cak | error | 0, 10, 13 | `test message` | a line in the middle of the file |
| last_line_no_newline | last_line_no_newline.cak | error | 0, 6, 10 | `test message` | last line, file has no trailing newline |
| eof_no_newline | eof_no_newline.cak | error | 0, 8, 8 | `test message` | zero-length span at end of file, no trailing newline: one caret just past the text |
| eof_trailing_newline | eof_trailing_newline.cak | error | 0, 9, 9 | `test message` | end of file after a trailing newline: points at the empty line 2 |
| empty_file | empty_file.cak | error | 0, 0, 0 | `test message` | empty file |
| multiline_span | multiline_span.cak | error | 0, 0, 13 | `test message` | span crossing lines: carets stop at the end of the first line |
| crlf | crlf.cak | error | 0, 7, 8 | `test message` | CRLF line endings: no `\r` in the printed line |
| note_and_hint | note_main.cak, note_geom.cak | error | 0, 17, 29 | ``no overload of `dist` matches (Point, str)`` | note in a second file, then a hint |
| warning_only | warning_only.cak | warning | 0, 6, 7 | `test warning` | warning severity; `hasErrors` must be false afterwards |

`note_and_hint` details:
- note: span (1, 3, 7), message `candidate: fn dist(a: Point, b: Point)`
- hint: `the second argument must be a Point`

## Known gaps (no fixture yet)

- Tabs before the span: the caret padding is all spaces, so it misaligns.
- Non-ASCII text before the span: columns count bytes, not characters.

## Regenerating

The expected files were produced by running the printer at the time and
checked by hand. If the output format changes on purpose, regenerate them
and review the diff before accepting it.
