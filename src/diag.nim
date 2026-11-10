import std/strformat
import std/algorithm
import std/strutils
import std/sequtils
import std/sugar
import std/streams
import std/os

type Span* = object
  fileIndex*: int
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
  hints*: seq[string]

type AugFile* = ref object
  index*: int
  name*: string
  content*: string
  lineOffsets*: seq[int]

type DriverCtx* = ref object
  files: seq[AugFile]
  diagnostics: seq[Diagnostic]

proc addFile*(self: DriverCtx, fileName: string): AugFile =
  let content = readFile(fileName)
  var offsets: seq[int] = @[0]

  for i, c in content:
    if c == '\n':
      offsets.add(i + 1)

  result = AugFile(
    index: len(self.files), name: fileName, content: content, lineOffsets: offsets
  )
  self.files.add(result)

proc getSpanPos(self: DriverCtx, span: Span): (int, int) =
  let augFile = self.files[span.fileIndex]
  let row = upperBound(augFile.lineOffsets, span.start) - 1
  let startCol = span.start - augFile.lineOffsets[row]
  result = (row, startCol)

proc getDiagnosticHeader(self: DriverCtx, diag: Diagnostic): string =
  let augFile = self.files[diag.span.fileIndex]
  let (row, startCol) = self.getSpanPos(diag.span)
  result = fmt"{extractFilename(augFile.name)}:{row+1}:{startCol+1}: {$diag.severity}: {diag.message}"

proc emitDiagnostic[T](self: DriverCtx, diag: Diagnostic, output: T = stderr) =
  let augFile = self.files[diag.span.fileIndex]
  let (row, startCol) = self.getSpanPos(diag.span)

  var line: string
  if row == len(augFile.lineOffsets) - 1:
    line = augFile.content[augFile.lineOffsets[row] ..^ 1]
  else:
    line =
      augFile.content[augFile.lineOffsets[row] ..< (augFile.lineOffsets[row + 1] - 1)]
  line = line.strip(chars = {'\r'})

  var numCarets = diag.span.stop - diag.span.start
  if startCol + numCarets > len(line):
    numCarets = len(line) - startCol
  if (numCarets == 0):
    numCarets = 1

  output.writeLine(self.getDiagnosticHeader(diag))
  output.writeLine("    " & line)
  # doesnt handle tabs correctly in the source code
  output.writeLine("    " & " ".repeat(startCol) & "^".repeat(numCarets))

proc emitDiagnostics*[T](self: DriverCtx, output: T = stderr) =
  for diag in self.diagnostics:
    self.emitDiagnostic(diag, output)

    for note in diag.notes:
      self.emitDiagnostic(note, output)

    for hint in diag.hints:
      output.writeLine("    hint: " & hint)

proc hasErrors*(self: DriverCtx): bool =
  result = self.diagnostics.any(d => d.severity == dsError)

proc reportError*(
    self: DriverCtx,
    span: Span,
    message: string,
    notes: seq[Diagnostic],
    hints: seq[string],
) =
  self.diagnostics.add(
    Diagnostic(
      severity: dsError, message: message, span: span, notes: notes, hints: hints
    )
  )

proc reportWarning*(
    self: DriverCtx,
    span: Span,
    message: string,
    notes: seq[Diagnostic],
    hints: seq[string],
) =
  self.diagnostics.add(
    Diagnostic(
      severity: dsWarning, message: message, span: span, notes: notes, hints: hints
    )
  )

proc newNote*(span: Span, message: string): Diagnostic =
  result = Diagnostic(severity: dsNote, message: message, span: span)

proc initSpan*(fileIndex: int, start: int, stop: int): Span =
  result = Span(fileIndex: fileIndex, start: start, stop: stop)
