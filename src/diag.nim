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
  let augFile = self.files[diag.span.fileIndex]
  let row = upperBound(augFile.lineOffsets, diag.span.start) - 1
  let startCol = diag.span.start - augFile.lineOffsets[row]
  result = (row, startCol)
proc getDiagnosticHeader(self: DriverCtx, diag: Diagnostic): string =
  let augFile = self.files[diag.span.fileIndex]
  let (row, startCol) = self.getDiagnosticPos(diag)
  result = fmt"{augFile.name}:{row+1}:{startCol+1}: {$diag.severity}: {diag.message}"

proc emitDiagnostic(self: DriverCtx, diag: Diagnostic) = 
  let augFile = self.files[diag.span.fileIndex]
  let (row, startCol) = self.getDiagnosticPos(diag)

  var line: string
  if row == len(augFile.lineOffsets) - 1:
    line = augFile.content[augFile.lineOffsets[row] ..^ 1]
  else:
    line =
      augFile.content[augFile.lineOffsets[row] ..< (augFile.lineOffsets[row + 1] - 1)]
  line = line.strip(chars = {'\r'})

  var numCarets = diag.span.stop - diag.span.start
  if (numCarets == 0):
    numCarets = 1
  if startCol + numCarets > len(line):
    numCarets = len(line) - startCol
  stderr.writeLine(self.getDiagnosticHeader(diag))
  stderr.writeLine("    " & line)
  stderr.writeLine("    " & " ".repeat(startCol) & "^".repeat(numCarets))
proc printDiagnostics*(self: DriverCtx) =
  for diag in self.diagnostics:
    self.emitDiagnostic(diag)

    for note in diag.notes:
      self.emitDiagnostic(note)
