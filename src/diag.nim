import std/strformat
import std/algorithm
import std/enumerate
import std/strutils

type Span* = ref object
  fileIndex*: uint8
  start*: int64
  stop*: int64

# type Note* = ref object
#   span*: Span
#   message*: string

type DiagnosticSeverity* = enum
  dsError
  dsWarning
  dsNote

type Diagnostic* = ref object
  severity*: DiagnosticSeverity
  message*: string
  span*: Span
  notes*: seq[Diagnostic] # each must have severity dsNote, empty notes

type AugFile* = ref object
  name*: string
  content*: string
  lineOffsets*: seq[int64]

type DriverCtx* = ref object
  files: seq[AugFile]
  diagnostics: seq[Diagnostic]

proc addFile(self: DriverCtx, fileName: string) =
  let f = open(fileName)
  let content = f.readAll()
  var offsets: seq[int64] = @[0]

  for i, c in enumerate(content):
    if c == '\n':
      offsets.add(int64(i) + 1)

  self.files.add(AugFile(name: fileName, content: content, lineOffsets: offsets))

proc getDiagnosticHeader(self: DriverCtx, diag: Diagnostic): string =
  let augFile = self.files[diag.span.fileIndex]
  let row = upperBound(augFile.lineOffsets, diag.span.start) - 1
  let startCol = diag.span.start - augFile.lineOffsets[row] + 1
  var sev = $diag.severity
  sev.removePrefix("ds")
  sev = sev.toLower()
  result = fmt"{augFile.name}:{row+1}:{startCol+1}: {sev}: {diag.message}"

proc printDiagnostics(self: DriverCtx) =
  for diag in self.diagnostics:
    let augFile = self.files[diag.span.fileIndex]
    let row = upperBound(augFile.lineOffsets, diag.span.start) - 1
    let startCol = diag.span.start - augFile.lineOffsets[row] + 1
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
