import std/strformat
import std/algorithm
import std/strutils
import std/sequtils
import std/sugar

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
  hints*: seq[string]

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

proc getSpanPos(self: DriverCtx, span: Span): (int, int) =
  let augFile = self.files[span.fileIndex]
  let row = upperBound(augFile.lineOffsets, span.start) - 1
  let startCol = span.start - augFile.lineOffsets[row]
  result = (row, startCol)

proc getDiagnosticHeader(self: DriverCtx, diag: Diagnostic): string =
  let augFile = self.files[diag.span.fileIndex]
  let (row, startCol) = self.getSpanPos(diag.span)
  result = fmt"{augFile.name}:{row+1}:{startCol+1}: {$diag.severity}: {diag.message}"

proc emitDiagnostic(self: DriverCtx, diag: Diagnostic) = 
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

  stderr.writeLine(self.getDiagnosticHeader(diag))
  stderr.writeLine("    " & line)
  # doesnt handle tabs correctly in the source code
  stderr.writeLine("    " & " ".repeat(startCol) & "^".repeat(numCarets))

proc printDiagnostics*(self: DriverCtx) =
  for diag in self.diagnostics:
    self.emitDiagnostic(diag)

    for note in diag.notes:
      self.emitDiagnostic(note)

    for hint in diag.hints:
      stderr.writeLine("    hint: " & hint)

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
