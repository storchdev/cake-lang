import diag
import std/unittest
import std/streams
import std/os

suite "diagnostics":
  setup:
    let table = @[
      ("mid_first_line", diag.dsError, (0,4,5), "test message"),
      ("middle_line", diag.dsError, (0,10,13), "test message"),
      ("last_line_no_newline", diag.dsError, (0,6,10), "test message"),
      ("eof_no_newline", diag.dsError, (0,8,8), "test message"),
      ("eof_trailing_newline", diag.dsError, (0,9,9), "test message"),
      ("empty_file", diag.dsError, (0,0,0), "test message"),
      ("multiline_span", diag.dsError, (0,0,13), "test message"),
      ("crlf", diag.dsError, (0,7,8), "test message"),
      ("note_and_hint", diag.dsError, (0,17,29), "no overload of `dist` matches (Point, str)"),
      ("warning_only", diag.dsWarning, (0,6,7), "test warning")
    ]

    let fixtureDir = currentSourcePath().parentDir / "diag/"

  test "fixtures match":

    for row in table:
      let driver = diag.DriverCtx()
      let _ = driver.addFile(fixtureDir & row[0] & ".cak")
      let tup = row[2]
      let span = diag.Span(fileIndex: tup[0], start: tup[1], stop: tup[2])
      if row[1] == diag.dsError:
        driver.reportError(span, row[3], @[], @[])
      else:
        driver.reportWarning(span, row[3], @[], @[])
      
      let expected = readFile(fixtureDir & row[0] & ".expected")
      let tmpFile = newStringStream()
      driver.emitDiagnostics(tmpFile)

      check expected == tmpFile.readAll()


# | mid_first_line | mid_first_line.cak | error | 0, 4, 5 | `test message` | first line, middle |
# | middle_line | middle_line.cak | error | 0, 10, 13 | `test message` | a line in the middle of the file |
# | last_line_no_newline | last_line_no_newline.cak | error | 0, 6, 10 | `test message` | last line, file has no trailing newline |
# | eof_no_newline | eof_no_newline.cak | error | 0, 8, 8 | `test message` | zero-length span at end of file, no trailing newline: one caret just past the text |
# | eof_trailing_newline | eof_trailing_newline.cak | error | 0, 9, 9 | `test message` | end of file after a trailing newline: points at the empty line 2 |
# | empty_file | empty_file.cak | error | 0, 0, 0 | `test message` | empty file |
# | multiline_span | multiline_span.cak | error | 0, 0, 13 | `test message` | span crossing lines: carets stop at the end of the first line |
# | crlf | crlf.cak | error | 0, 7, 8 | `test message` | CRLF line endings: no `\r` in the printed line |
# | note_and_hint | note_main.cak, note_geom.cak | error | 0, 17, 29 | ``no overload of `dist` matches (Point, str)`` | note in a second file, then a hint |
# | warning_only | warning_only.cak | warning | 0, 6, 7 | `test warning` | warning severity; `hasErrors` must be false afterwards |
   
    
