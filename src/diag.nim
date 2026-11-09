import std/strformat
import std/algorithm
import std/strutils

type Span* = object
  fileIndex*: uint8
  start*: int
  stop*: int

# type Note* = ref object
#   span*: Span
#   message*: string

type DiagnosticSeverity* = enum
  dsError = "error"
  dsWarning = "warning"
  dsNote = "note"

type Diagnostic* = ref object
  severity*: DiagnosticSeverity
  message*: string
  span*: Span
  notes*: seq[Diagnostic] # each must have severity dsNote, empty notes

type AugFile* = ref object
  name*: string
  content*: string
  lineOffsets*: seq[int]

type DriverCtx* = ref object
  files: seq[AugFile]
  diagnostics: seq[Diagnostic]

proc addFile*(self: DriverCtx, fileName: string) =
  let content = readFile(fileName)
  var offsets: seq[int] = @[0]

  for i, c in content:
    if c == '\n':
      offsets.add(i + 1)

  self.files.add(AugFile(name: fileName, content: content, lineOffsets: offsets))

proc getDiagnosticPos(self: DriverCtx, diag: Diagnostic): (int, int) =
proc getDiagnosticHeader(self: DriverCtx, diag: Diagnostic): string =
  let augFile = self.files[diag.span.fileIndex]
  let row = upperBound(augFile.lineOffsets, diag.span.start) - 1
  let startCol = diag.span.start - augFile.lineOffsets[row]
  result = (row, startCol)
  result = fmt"{augFile.name}:{row+1}:{startCol+1}: {$diag.severity}: {diag.message}"

  let (row, startCol) = self.getDiagnosticPos(diag)
proc printDiagnostics*(self: DriverCtx) =
  for diag in self.diagnostics:
    let augFile = self.files[diag.span.fileIndex]
    let numCarets = diag.span.stop - diag.span.start
    var line: string
    if row == len(augFile.lineOffsets) - 1:
      line = augFile.content[row ..^ 1]
    else:
      line = augFile.content[row ..< augFile.lineOffsets[row + 1]]

    stderr.writeLine(self.getDiagnosticHeader(diag))
    stderr.writeLine("    " & line)
    stderr.writeLine("    " & " ".repeat(startCol) & "^".repeat(numCarets))

    for note in diag.notes:
      stderr.writeLine(self.getDiagnosticHeader(note))
