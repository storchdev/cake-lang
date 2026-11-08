# CP Language Spec — Draft v0.1

Nov 2, 2026 · @Hudson Shi

## Goals and principles

This is a statically typed, compiled language for competitive programming and Advent of Code, built to get from idea to accepted solution with the least friction. It targets LLVM and is not meant for large, durable software, though a program can import helper files of its own.

**Goals**

- Fast to write: no required type annotations, little ceremony, short names.
- Fast to run: native machine integers and floats unless the program opts into big or modular numbers.
- Fluent chaining over arrays, maps, strings and ranges.
- Strict compile-time checking after inference, with errors that point at the cause.
- Built-in input reading, grid, graph and matrix helpers for the problems it is made for.

**Non-goals**

- Packages, package managers or project manifests. A file can import other files, and that is all.
- Class hierarchies and inheritance.
- Manual memory management.
- User-written generic syntax such as `<T>` or trait bounds.

**Principles**

1. Writability above maintainability.
2. Python's feel for numbers, with static types and native speed.
3. One naming scheme per feature family: every input function starts with `read_`.
4. Avoid JavaScript's traps: no implicit string coercion, no lexicographic default sort, no truthiness surprises.
5. Keep the compiler small: write as much of the library as possible in the language itself.

## Syntax basics

Braces delimit blocks and newlines end statements. Functions and lambdas follow one rule: an `= expr` or `|x| expr` body returns its expression, and a braced body uses `return`. Other braced blocks used as values, in `if`, `match` and `try`, yield their last expression. A program is a file of top-level statements and functions, run in order, with no `main`. It can import other files; see Imports.

```
// assignment declares a variable the first time; types are inferred
n = read_int()
total = 0
for i in 0..n { total += i * i }

// two function forms
fn sq(x) = x * x          // expression body: its value is returned
fn find(arr, t) {         // braced body: statements, explicit return
  for i in 0..arr.len() {
    if arr[i] == t { return i }
  }
  return null             // so find returns int?
}

f = |a, b| a + b
label = if total > 9 { "big" } else { "small" }
a, b = b, a + b           // parallel assignment
if 0 <= r < n { ... }     // chained comparison
outer: for r in 0..n {    // labeled loop
  for c in 0..m { if g[r][c] == 'S' { break outer } }
}
```

- **Bindings:** `x = expr` declares `x` the first time and reassigns it afterwards. Assigning to a name that exists in an enclosing scope of the same function, including one captured by a lambda, reassigns it; otherwise it declares a new local. `let x = expr` is optional and always creates a new binding in the current scope, which is how to shadow. Destructuring needs no parentheses: `a, b = b, a + b` evaluates the right side first. The compiler warns about a variable that is assigned but never read, which catches typos. There is no `const`.
- **Control flow:** `if`/`else`, `match` and `try`/`catch` are expressions; `while`, `for x in iterable`, `break` and `continue` are statements. `for` destructures: `for (u, v) in edges`, `for (k, v) in m`, `for (i, x) in a.enumerate()`. Each iteration gets a fresh loop variable, so a closure made inside the loop keeps that iteration's value, not the last one.
- **Labeled loops:** `outer: for ...` names a loop, and `break outer` or `continue outer` acts on it from any depth.
- **Chained comparisons:** `0 <= r < n` means `0 <= r and r < n`, with `r` evaluated once.
- **Ranges:** `a..b` excludes `b`, `a..=b` includes it, and both are lazy. `a..` has no end, so `for t in 1.. { ... }` loops until `break`. Slices may leave out either end: `a[i..]`, `a[..j]`.
- **Function and lambda bodies:** one rule for both. `fn name(args) = expr` and `|x| expr` return `expr`. `fn name(args) { ... }` and `|x| { ... }` are blocks of statements with no implicit return, so they use `return`. Falling off the end returns nothing (unit, which is not `null`, so `x = print(1)` is an error), and it is an error if some paths return a value and others do not.
- **`return`** exits the function with a value and has type never, so `x = if ok { 5 } else { return -1 }` type-checks. The return type unifies every `return` and, for expression-bodied functions, the body. Inside a lambda, `return` exits the lambda only.
- **Top level and scope.** Top-level variables are globals, visible inside every function, so input read at the top can be used by `fn dfs(u)` below it. Functions can be called before the line that defines them. Reading a global before its first assignment, as when a function runs above the line that sets it, traps with kind `"unset"` and names the variable. A `fn` may also be defined inside another function, where it can recurse and captures variables by reference like a lambda.
- **Comments:** `//` to the end of the line.

## Type system

Types are inferred with Hindley-Milner-style unification, so users almost never write them, yet every program is fully checked at compile time before code generation.

- **Implicit generics.** A function with unconstrained parameters is generic: `fn swap(p) = (p.1, p.0)` works for any pair. Each call site gets its own specialized copy (monomorphization), so there is no runtime cost.
- **Template-style operator checks.** Inside a generic body, `a + b` is resolved when the function is instantiated with concrete types. So `fn add(a, b) = a + b` works for ints, floats and strings, and `add([1], 5)` is an error at the call. Mixed `int` and `float` arguments apply the numeric widening rule.
- **Trade-off.** Errors in generic code appear at the call site, and a generic function nobody calls is never fully checked. The library therefore needs a test file that calls every function.
- **Chaining helps inference.** The receiver is checked before the arguments, so in `pts.map(|p| p.x)` the element type of `pts` is known when the lambda is checked. A bare `f = |p| p.x` that is never used is an error.
- **Empty literals** such as `[]` and `{}` take their type from later use, and it is an error if none is found.
- **Field access is structural.** `fn norm(p) = p.x*p.x + p.y*p.y` works on any tuple or record that has `x` and `y`; the field is checked at instantiation. Field names can be shortened to a unique prefix; see Named arguments and fields.
- **Optionals.** `T?` is a value or `null`, and whether a slot is optional is inferred; see Errors and optionals.
- **No union types.** `if c { 1 } else { "a" }` and `[1, "a"]` are errors, not `int | string`. Untagged unions would cost principal types, catch fewer bugs and put a runtime tag on every value. Variant types, `type Expr = Num(v) | Add(l, r)`, cover the cases that need alternatives.

**Optional annotations** are compiler-checked, never cosmetic. They constrain and do not convert.

```
x: u8 = 0                  // pins a numeric type; 300 here is an error
seen: {int: bool} = {}     // fixes an empty literal
visited: {(int, int)} = set()   // a set type
g: fn(int) -> int = sq     // a function type: takes an int, returns an int
fn f(a: [int]) -> int      // checked against the body
p: (int, _) = (1, "a")     // _ leaves part of the type to inference
y = x as int               // explicit conversion
```

Nothing requires an annotation except `extern` declarations, empty literals whose type is never determined, and overloads that differ only by type, which dispatch on their annotated parameters. Examples and the library should use annotations only where they carry meaning.

- **Type syntax.** `[T]` array, `{K: V}` map, `{T}` set, `(A, B)` tuple, `(x: A, y: B)` named tuple, `T?` optional, and `fn(A, B) -> R` for functions, which is a declaration with the names removed.
- **Type aliases.** `type Pos = (int, int)` names a type. When the right side is a type, `type` makes an alias; when it lists constructors like `Num(v) | Add(l, r)`, it declares variants (see Variant types). An alias of a number type also converts: with `type M = Mod(1e9 + 7)`, `M(5)` is a value of `M`.

## Errors and optionals

Errors are crashes that can be caught, as in Python. Missing values are `null`, which belongs only to optional types. There is no `None` type to write and no exception hierarchy.

**Errors**

Every runtime failure is the same kind of trap: overflow, an out-of-bounds index, a missing map key, division by zero, reading past the end of input, unwrapping `null` with `!`, and `raise`. An uncaught trap prints its message and source line and exits with a nonzero status.

```
x = try { parse(line) } catch e { print(e.msg); 0 }   // an expression, like if
n = try int(s) ?? 0                                   // bare try: T?, null on error
raise "no path found"                                 // type never, like return
assert(lo <= hi, "bad range {lo} {hi}")                // an ordinary function
try { run() } catch e { if e.kind != "eof" { raise e } }   // rethrow
```

- **One error type.** `e` has `.kind` (`"overflow"`, `"index"`, `"key"`, `"div"`, `"eof"`, `"null"`, `"match"`, `"assert"`, `"unset"` or `"raise"`) and `.msg`. There are no typed catch clauses; test `e.kind` and rethrow.
- **`try { ... } catch e { ... }`** is an expression whose branches unify like `if`. `catch` without a name is allowed.
- **Bare `try expr`** yields `T?`, with `null` if `expr` traps. It binds tighter than `??`, so `try int(s) ?? 0` reads as expected.
- **`raise "msg"`** has type never, so it fits any branch. `raise e` rethrows a caught error unchanged.
- **`assert(cond, msg)`** is a library function, not a keyword. It traps with kind `"assert"` when `cond` is false, and `msg` is optional.
- **Implementation.** The runtime never frees, so unwinding has no cleanup to do and `setjmp`/`longjmp` in the C runtime is enough; no LLVM landing pads are needed. Each `try` body compiles to a closure called through `rt_try(fn, env)`, so locals it touches already live in the closure environment and `longjmp` cannot clobber them. Code outside a `try` pays nothing.
- **Stack overflow** from deep recursion is not catchable. The runtime runs the program on a large stack and reports `stack overflow` through a `sigaltstack` handler instead of a bare segfault.

**Optionals**

`null` is a value of every optional type `T?`. A bare `null` whose `T` is never determined is an error, like an empty literal. Unit, the result of a function that returns nothing, is separate from `null`.

```
best = null                     // best: int?, from later use
for x in xs { if best == null or x < best { best = x } }
fn find(arr, t) { ... return i ... return null }   // returns int?
record Node(val, left, right)   // Node(1, null, null) makes left and right Node?
```

- **Inferred optionality.** Each type variable carries a nullable flag that only goes from false to true. If `null`, a `T?` value or a bare `try` flows into a variable, field, parameter or return, that slot becomes `T?`. Because the flag never goes back, it is solved inside unification without general subtyping.
- **Lifting.** A plain `T` stored into a `T?` slot is wrapped automatically. A `T?` used where `T` is required is an error until it is narrowed.
- **Using an optional:** `x ?? d` supplies a default, `x!` unwraps or traps with kind `"null"`, and `x?.f` gives `null` if `x` is `null`. `??` on a non-optional is an error, since it usually means a type mistake.
- **Narrowing.** After `x != null` or `x == null` in an `if`, `while`, `and` or `or`, a local is treated as `T` on the non-null path until it is reassigned. `while node != null { node = node.next }` type-checks.
- **Representation.** An optional record is a nullable pointer, so it costs nothing. Other optionals carry a tag next to the value, which also keeps `T??` correct, as with `m.get(k)` on a `{K: int?}`.

## Numbers

Numbers are statically typed machine types by default, with Python-style arithmetic rules layered on top. Arbitrary precision is a separate type, never automatic promotion, so arrays stay compact and loops stay vectorizable.

| Type | Meaning | Notes |
| --- | --- | --- |
| `int` | Default integer | Alias for `i64`; changed by pragma |
| `i8` `i16` `i32` `i64` `u8` `u16` `u32` `u64` | Fixed-width integers | Used when pinned by annotation or FFI |
| `float` | Default float | `f64`; `f32` also available |
| `big` | Arbitrary-precision integer | GMP integer (mpz) |
| `Mod(m)` | Integer modulo `m` | `+ - *` reduce automatically; `**` is fast power; `m` may be read from input |
| `rat` | Exact rational | GMP rational (mpq), for exact linear solves; later milestone |
| `bigfloat` | Arbitrary-precision float | GMP float (mpf); last priority |

**Rules**

1. A literal is "some number" until constrained. If nothing pins it, whole literals become `int` and fractional ones `float`. Underscores separate digits, as in `1_000_000_007`, and an exponent literal with a whole value, such as `1e9` or `2e5`, is a whole literal, so `INF = 1e18` is an `int`. An integer literal too large for `int` is a compile error with a hint to annotate `big`; where the context is already `big`, it is fine. The program-level pragma `#default int = big` changes the fallback, and because `int` is an alias resolved before checking, the whole program flips with no other change.
2. Implicit widening only: `u8` to `int` to `float`, and `int` to `big`, `Mod(m)` or `rat`, so `x: big = 1` and `total + count` just work. Arithmetic on integer types narrower than `int` promotes to `int`, so `s[i] - '0'` is an `int`, and storing back into a narrow slot is range-checked. Lengths and indices are `int`, so `i < a.len()` never mixes signed and unsigned. Narrowing and mixing signed with unsigned are compile errors; use `as`.
3. `/` always yields a float, `//` is floor division, and `%` takes the sign of the divisor, so `-7 % 3 == 2`.
4. `**` is power. An integer to an integer power stays an integer, and a negative exponent traps, except on `Mod(m)`, where `x ** -1` is the modular inverse and traps if none exists. Bit operators are `& | ^ ~ << >>`.
5. Overflow traps, using LLVM's overflow-checking intrinsics. Code that wants wraparound, such as hashing, uses the wrapping types below instead of turning checks off.
6. `big`, `rat` and `bigfloat` are GMP's `mpz_t`, `mpq_t` and `mpf_t`, so values cross the FFI boundary to GMP-using C code unchanged. The runtime links GMP instead of a hand-written bignum.
7. **Conversions.** `as` converts between numeric types: `x as int` truncates a float toward zero and is range-checked. Parsing is a function named after the type: `int(s)`, `float(s)` and `big(s)`, which also work as `.map(int)` and, through uniform call syntax, as `s.int()`. `text(b)` turns a byte into a one-character string, since `str(b)` gives its number; `text(row)` and `text(grid)` do the same for a byte array and a byte grid, which becomes lines. `text` is an ordinary overloaded function, so `b.text()` works too and you can add overloads for your own types. There is no `ord`: `'a'` is already a `u8`, so `s[i] - 'a'` needs no conversion.
8. **Limits.** `int.max`, `int.min` and the same on every fixed-width type, plus `inf` for floats. Arithmetic past `int.max` traps, which catches a careless `dist[u] + w` on an unvisited node.

**Modular arithmetic.** `Mod(m)` is a number type whose `+ - * **` are always reduced modulo `m`, so a problem that says "print the answer modulo 1,000,000,007" needs no `%` anywhere:

```
type M = Mod(1e9 + 7)               // reads like the problem statement
ways: [M] = [0] * (n + 1)
ways[0] = 1
for i in 1..=n { ways[i] = ways[i - 1] * 2 + ways[i // 2] }
print(ways[n])                      // already reduced; cannot overflow

n, m = read_ints(2)                 // a modulus given in the input
type R = Mod(m)
```

- `m` must be a literal or a top-level variable that is never reassigned, so a `Mod(m)` type always means one modulus. A function parameter is not allowed: `fn f(m) { x: Mod(m) = 5; return x }` would let `f(7) + f(11)` add values reduced by different moduli under one type. `Mod(p)` and `Mod(q)` are different types, so mixing them is a compile error.
- The modulus is evaluated exactly, so `Mod(1e9 + 7)` and `Mod(2**64)` are fine even though `2**64` does not fit in an `int`.
- **Wrapping types.** `wrap8`, `wrap16`, `wrap32` and `wrap64` are built-in aliases for `Mod(2**8)` to `Mod(2**64)`. They compile to plain machine arithmetic that wraps around, which is what hashing wants: `h: wrap64 = 0; for b in s.bytes() { h = h * 131 + b }`.
- Values are plain integers, and the modulus lives with the type, so `[Mod(m)]` is as compact as `[int]`.
- A modulus known at compile time lets LLVM replace division with multiplication. A modulus read at run time uses Barrett reduction with a constant computed once, which is close in speed.

## Built-in collections

Strings, arrays, maps and sets are built in, homogeneous, and hashable or comparable structurally. There is no `char` type.

| Type | Literal | Notes |
| --- | --- | --- |
| String | `"abc"`, `"x = {x}"`, `r"raw"` | Immutable bytes; every literal interpolates; see Strings and formatting |
| Array `[T]` | `[1, 2, 3]` | Growable and bounds-checked; `a[-1]` is the last element; `a[i..j]` slices; `+` concatenates and `* n` repeats |
| Map `{K: V}` | `{1: "a"}` | Hash map; keys may be ints, strings or tuples |
| Set | `set(1, 2, 3)` | Hash set; `x in s` tests membership; `\| & - ^` are union, intersection, difference and symmetric difference |
| Deque, priority queue | `deque()`, `heap()` | Library types; `heap` is a min-heap with an optional key function |
| Ordered map and set | `omap()`, `oset()` | Sorted keys with `lower_bound`, which Python lacks |

**Conventions**

- `x in coll` works for arrays, strings, sets and map keys.
- **Negative indices are literal only.** `a[-1]` and `a[-2..]` count from the end, but a computed index that comes out negative traps, so `dp[i - 1]` at `i = 0` is an error instead of a silent read of the last element.
- **A lookup that can miss returns an optional:** `m.get(k)`, `s.find(x)`, `a.find(pred)`, `a.position(pred)` and `bsearch`. `min` and `max` of an empty collection trap, as in Python.
- `m[k] += 1` on a missing key starts from zero for numeric values, which gives counters for free. The same goes for mutating a missing value in place: `m[k].push(x)` starts from `[]`, `m[k].add(x)` from an empty set and `m[k] += "s"` from `""`, which gives grouping for free. Reading a missing `m[k]` otherwise traps, while `m.get(k)` returns an optional, so `m.get(k) ?? 0` works.
- Fresh-row constructors prevent aliasing: `grid(n, m, 0)` and `[0] * n` allocate new rows, and `[[0] * m] * n` is a compile error.
- Strings have `.split(sep)`, `.trim()`, `.words()`, `.lines()`, `.bytes()`, `.contains(x)`, `.find(x)` and `.reverse()`.
- **`s.extract_ints()`** pulls every integer out of any text, in whatever numeric type the context asks for: `"Sensor at x=-3, y=17".extract_ints()` is `[-3, 17]`. A `-` is a minus sign only when it does not follow a digit, so the range `"3-7"` gives `[3, 7]`. `s.extract_floats()` does the same for decimals.
- `s[i]` returns the byte at `i` as a `u8`, and `'#'` is a `u8` byte literal, so `s[i] == '#'` and `s[i] - '0'` work with no char type. `s[i..j]` slices to a string. Indexing by UTF-8 code point, as `s.nth(i)`, is planned after v1.
- **Sorting returns a new array.** `a.sort()`, `a.sort_by(key)` and `a.reverse()` leave `a` alone and return the result, so they chain (`a.sort().reverse().take(3)`) and `x = a.sort()` is never a silent `null`. Sort in place with `a = a.sort()`. `a.sort(desc: true)` sorts descending, and `sort()` uses the element type's ordering, so `[int]` sorts numerically. Since the v1 runtime never frees, sorting a huge array many times in a loop can use a lot of memory; `a.sort_in_place()` exists for that case.

## Strings and formatting

Every string literal interpolates, like a Python f-string with no `f` prefix. The format spec after the colon covers what Python's does, but each setting is its own short word, so a spec reads left to right with no symbols to decode.

```
"x = {x}"            // any expression inside the braces, including "{m["a"]}"
"{x:.3}"             // 3.142: three digits after the point
"{n:r3 fill=0}"      // 007: right-align in width 3, padded with 0
"{name:l10}|"        // left-align in 10
"{n:bin r8 fill=0}"  // 00000101: binary, right-aligned in 8, padded with 0
"{x=}"               // x=5, for debugging
"{xs:.2}"            // [1.00, 2.50]: a spec on a container applies to each element
"{row:text}"         // #..#.: bytes as text
"{state:pp}"         // pretty-printed
"{grid:text i=4}"    // bytes as text, pretty-printed with indent 4
"{x:.{p}}"           // precision from a variable
r"\d+{2}"            // raw string: no interpolation, no escapes
"{{literal}}"        // {literal}
```

**Format spec**

A spec is a list of words separated by spaces. Each word sets one thing and can be recognised on its own, so the words can come in any order and each setting appears at most once.

```
{n:r3 fill=0}           {n:fill=0 r3}         // the same
{x:.2 r10}              {n:hex}               {n:, r12}
{grid:text pp}          {grid:text indent=4 lines=Many}
{n:b r8 f=0}            {n:bin r8 fill=0}     // the same: words are prefix-matched
```

| Word | Example | Output | Meaning |
| --- | --- | --- | --- |
| `.N` | `{x:.3}` | `3.142` | N digits after the point |
| `lN` `cN` `rN` | `{n:r5}`, `{s:c7}` | `   42`, `  ab   ` | Left, center or right in width N |
| `fill=C` | `{n:r3 fill=0}`, `{s:l6 fill=.}` | `007`, `ab....` | Pad with C instead of spaces; needs an alignment |
| `hex` `HEX` `bin` `oct` | `{n:hex}`, `{n:bin r8 fill=0}` | `ff`, `00000101` | Base 16 (lower or upper case), 2 or 8 |
| `sci` | `{x:.2 sci}` | `3.14e+00` | Scientific notation, only when asked for |
| `,` | `{n:,}` | `1,234,567` | Thousands separators |
| `text` | `{b:text}`, `{row:text}`, `{grid:text}` | `#`, `#..#.`, lines of text | Bytes read as characters, by calling `text(x)`; works on any type with a `text` overload |
| `pp` | `{x:pp}` | (multi-line) | The pretty form |
| `wrap=` `indent=` `lines=` `max=` | `{grid:text i=4}` | (multi-line) | Pretty-print options; any of them turns on the pretty form; see Printing and debugging |
| `=` after the expression | `{x=}`, `{x=:.2}` | `x=5`, `x=3.14` | Prints the expression's text, then its value |

- **Every word is prefix-matched,** like named arguments: `{n:b r8 f=0}` is `{n:bin r8 fill=0}` and `{row:t}` is `{row:text}`. The bare words `text`, `hex`, `HEX`, `bin`, `oct`, `sci` and `pp` all start with different letters, and so do the option names `fill`, `wrap`, `indent`, `lines` and `max`, so one letter is always enough. A prefix that fits two words is an error that lists them.
- **Options are `name=value`.** They use `=` rather than `:` because the spec already starts after a colon; in code, `pp(x, indent: 4)` uses the usual `:`.
- **`fill` takes one character,** including ones that mean something elsewhere in a spec: `fill=0`, `fill=.`, `fill=,`, `fill=#`. Space is the default, so it is never written.
- **Width needs an alignment.** `{n:5}` and `{n:03}` are compile errors with a hint (`write {n:r5}` or `{n:r3 fill=0}`), since a bare number says nothing about which side is padded. This drops Python's hidden rule that numbers default to the right and strings to the left. Alignment is `l`, `c` or `r`, not Python's `< ^ >`.
- **`.N` means decimal places.** In Python, `{x:.3}` means three significant digits, so `1234.5` becomes `1.23e+03`. Here it is always fixed-point. `.N` on an integer widens it to a float; on a string it is an error.
- **Zero fill keeps the sign first.** `{-7:r3 fill=0}` is `-07`, where Python gives `0-7`.
- **Type-checked.** The spec is checked against the value's type at compile time: `{s:hex}` on a string, a setting given twice, or an unknown word is an error that lists the valid words.
- **Values from expressions.** Any part of a spec can be `{expr}`, as in Python: `{x:.{p}}`, `{s:r{w}}`, `{grid:i={k}}`, `{s:r9 fill={c}}`. This also covers a fill that is a space or a brace. `x.fmt(".{p} r10")` takes a whole spec as a string.
- **Raw strings,** `r"..."`, have no interpolation and no escapes, for regex-like or brace-heavy text.
- **Multi-line strings,** `"""..."""`, drop the first newline and the indentation common to every line, so they can be indented with the code. `r"""..."""` is the raw form.

**Rounding and float output**

- **Ties round away from zero everywhere.** `round(2.5) == 3`, and `{0.125:.2}` is `0.13`, where Python gives `2` and `0.12`. Formatting works from the float's exact binary value, so the runtime uses its own exact float-to-decimal routine instead of `snprintf`.
- `round(x)` returns an `int`; `round(x, n)` returns a `float`.
- **Default float output.** `print(x)` and `"{x}"` use the shortest text that reads back as the same float, as Python's `repr` does, so `0.1 + 0.2` prints `0.30000000000000004` and `3.0` prints `3.0`. It never uses scientific notation, since some contest checkers reject `1e-07`; `0.0000001` prints in full. Contest output usually uses `{x:.9}` anyway.

## Printing and debugging

Every value prints the way it would be written in code, so what you read back is the syntax you write. Debug printing goes to stderr, so it never corrupts an answer on the judge.

**Default printing**

`print(x)`, `"{x}"` and `str(x)` produce:

| Value | Output |
| --- | --- |
| Array, tuple, named tuple | `[1, 2, 3]`, `(1, "a")`, `(x: 1, y: 2)` |
| Record, variant | `Point(x: 1, y: 2)`, `Add(l: Num(v: 1), r: Num(v: 2))` |
| Map, set | `{1: "a", 2: "b"}`, `set(1, 2)` |
| Optional, bool | the value or `null`, `true` |

- **Bytes print as numbers**, since a `u8` may be a count as easily as a character. `{b:text}` prints one as a character, `{row:text}` prints a byte array as text and `{grid:text}` a byte grid as lines; `b.text()` gives the same string in code.
- **Strings are quoted inside containers, not at the top level.** `print("hi")` prints `hi`, while `print(["hi"])` prints `["hi"]`, which makes a `"1"` versus `1` bug visible.
- **Maps and sets print in sorted key order** when their keys are comparable, so output is deterministic.
- **Cycles** through records print as `<cycle Node>` instead of looping forever.
- **`str` hooks** override the form for any type, including inside containers; see overloading.
- **Contest output** uses `join`, which calls `str` on each element: `print(a.join(" "))` prints `1 2 3`.

**Debug output (stderr)**

```
dbg(x)                      // [line 12] x = 5, and returns x
total = xs.map(f).dbg().sum()   // [line 13] xs.map(f) = [...], mid-chain
pp(state)                   // pretty-printed
pp(row, "text", lines: Many)  // element spec, then options
eprint("dist", d)           // print, but to stderr
```

- **`dbg(x)`** prints the line number, the expression's source text and its value, then returns the value unchanged, so it can be dropped into any expression or chain. Rust's `dbg!` is the model.
- **`pp(x)`** prints on one line if it fits; otherwise it breaks the value across lines, one element or field per line. An optional second argument is an element spec, as in `{}`.

**Pretty-print options** are written the same way everywhere: as a program-wide default, in a call, or inside a string.

```
#pp(indent: 4, wrap: 120)             // default for the whole program
pp(state, lines: Many, max: 20)       // this call only
pp(state, l: Many, m: 20)             // the same, with shortened names
"{state:lines=Many max=20}"           // the same options inside a string
"{state:l=Many m=20}"                 // shortened there too
s = state.pretty(lines: Many)         // the pretty form as a string
```

| Option | Meaning | Default |
| --- | --- | --- |
| `wrap` | Break a value across lines when it would pass this column | 80 |
| `indent` | Spaces per nesting level | 2 |
| `lines` | `Auto` breaks only when too wide; `One` never breaks; `Many` always does | `Auto` |
| `max` | Most elements shown per container, as in `[3, 1, 4, ... 99,950 more]` | 100 |

The names start with different letters, so each can be shortened to one: `w`, `i`, `l`, `m`. The line width is called `wrap` so it is not confused with the padding width `r10` in a format spec.

- `One`, `Many` and `Auto` are the field-less variants of a built-in `type Lines = One | Many | Auto`, so they need no quotes.
- `x.pretty(...)` returns the pretty form as a string, and `pp(x, ...)` writes `x.pretty(...)` to stderr.
- `print` ignores these options, because it writes answers.
- `dbg` and `pp` always quote strings, so stray whitespace is visible.

**Views for grids, trees and graphs**

These are library functions in the language itself, called as methods. They print to stderr.

- **Grids.** `g.show()` on a `[[T]]` or `[str]` prints an aligned block with no brackets. Byte grids print as characters, `bool` grids as `#` and `.`, and numbers right-aligned in equal-width columns, which is how Advent of Code draws its puzzles.

  ```
  #..#.
  .##..
  ```

- **Trees.** `t.show()` draws a tree like the `tree` command, and `t.show(|v| "{v}: {val[v]}")` labels each node.

  ```
  1
  ├── 2
  │   ├── 4
  │   └── 5
  └── 3
  ```

  It works on library trees (`tree(n)`), and on recursive records and variants with no extra code: the compiler already derives their printing and knows which fields refer back to the same type, so `show(root)` draws a binary search tree or an expression tree directly. For anything else, `show_tree(root, |n| n.kids)` takes a function that returns the children.
- **Graphs.** `g.show()` prints adjacency lists, one node per line, such as `1 -> 2 (w=5), 3`. `g.dot()` returns Graphviz text for larger graphs. Drawing arbitrary graphs as 2D text is a hard layout problem and out of scope; a layered drawing for small DAGs may come later.

## Tuples, named tuples and records

Tuples are immutable values and records are mutable references, following Python's split. Tuples are passed by value and records by pointer. Both are built in, with no object-oriented features.

| Kind | Example | Semantics |
| --- | --- | --- |
| Tuple | `(1, "a")` | Immutable value, passed by value; `.0`, `.1`; hashable; ordered lexicographically; stored flat |
| Named tuple | `(x: 1, y: 2)` | A tuple with names; `.x` or `.0`; same value semantics |
| Record | `record Point(x, y)` | Mutable reference, passed by pointer; nominal name; `p.x = 5` mutates in place |
| Variant type | `type Expr = Num(v) \| Add(l, r)` | Several records grouped under one name; tested with `is` or `match` |

- **Destructuring:** `a, b = pair`, `(a, b) = pair` and `[n, m] = read_ints(2)`.
- **Constructing records:** arguments are positional or named, and fields may have defaults: `record State(pos, steps = 0)` is built with `State(p)`, `State(p, 3)` or `State(pos: p, steps: 3)`, which is also how records print.
- **Tuples are vectors.** On tuples of numbers with the same shape, `+` and `-` work element by element, `*` and `//` by a number scale, and `-p` negates, so grid movement is `np = p + d`. A `[[T]]` grid can be indexed by a pair, `g[p]` for `g[p.0][p.1]`. Comparison stays lexicographic. Arrays do not do this, since `+` already concatenates them and `*` repeats them; numeric vectors of any length belong to the matrix library.
- **Changing one field:** `p.with(x: 5)` returns a copy of a tuple or record with that field replaced, since tuples cannot be mutated.
- **Equality, hash, order and printing** are derived structurally for every tuple and record. Override them with the hooks described under overloading.
- **Assignment never copies.** `b = a` makes two names for one record, and passing to a function passes the reference. Use `.copy()` for a shallow copy and `.deepcopy()` for a full one.
- **Recursive types need no special handling,** since a record is already a reference: `record Node(val, left, right)` with `left` and `right` holding a `Node` or `null` just works, and field types are inferred.
- **Safe as keys.** `(r, c)` works as a map key or set element. A tuple that holds an array still shares that array, like Go slices. Using a record type as a map key or set element is a warning, because mutating a record after inserting it breaks the map; use a tuple instead.
- **C compatibility:** records pass to C by pointer and named tuples by value; see the FFI section.

**Variant types**

`type Expr = Num(v) | Add(l, r)` declares several records at once and groups them under one name, so a `[Expr]` can hold any of them. This is how to type expression trees, instruction lists and nested data such as Advent of Code's packet lists, since there are no unions.

```
type Shape = Circle(center, r) | Rect(corner, w, h)

s = Rect(corner: (0, 0), w: 3, h: 4)    // named or positional, like records
if s is Rect { print(s.w * s.h) }       // narrowed to Rect, so fields work by name
area = match s {
  Circle(c, r):  3.14 * r * r         // patterns bind by position
  Rect(_, w, h): w * h
}

type Expr = Num(v) | Add(l, r) | Mul(l, r)
type Instr =                            // long types: one variant per line
  | Inc(reg)
  | Jnz(reg, off)
  | Halt
```

- **Fields are named.** In `Circle(center, r)`, `center` and `r` are field names, and fields may be annotated like parameters: `Circle(center: (int, int), r: float)`.

- **Each variant is a record.** It is constructed, mutated, compared, hashed and printed exactly like one, with field types inferred. Variants order by declaration order, then by fields. A variant with no fields, like `Halt`, is a single shared value. A `type` needs at least two variants; a single one is a `record`.
- **`x is Add`** tests the variant. In an `if`, `while`, `and` or `or`, it narrows a local the same way a `null` check does, so the variant's fields can be used directly.
- **No exhaustiveness checking.** Code that forgets a variant fails at run time, like every other mistake.

## Pattern matching

`match` takes a value apart by shape, in the spirit of Python 3.10. It works on any value, not only variants, and its most common use is splitting input lines.

```
match line.words() {
  ["inc", r]:      regs[r] += 1
  ["jnz", r, off]: if regs[r] != 0 { pc += int(off) - 1 }
  ["out", ..rest]: print(rest.join(" "))
  _:               raise "bad line: {line}"
}

fn eval(e) = match e {
  Num(v):    v
  Add(l, r): eval(l) + eval(r)
  Mul(l, r): eval(l) * eval(r)
}

d = match m.get(k) { null: 0; v if v > 0: v; _: -1 }
```

- **Patterns:** literals (numbers, strings, `'#'` bytes), names that bind, `_`, tuples, arrays of a fixed length with an optional `..rest`, variants such as `Add(l, r)`, and `null`. They nest.
- **Arm syntax** is `pattern: body`, like Python's `case pattern:` without the keyword. The colon cannot be misread: inside `match { }` there are only arms, and a colon inside a pattern's parentheses, as in `Rect(w: x)`, belongs to that pattern. A `match` body looks like a map literal on purpose, since it reads as a lookup table.
- **Guards:** `pat if cond: ...` adds a condition.
- **Arms** are tried in order and separated by newlines or `;`. An arm's body is an expression or a braced block.
- **As an expression,** the arm bodies unify like `if` branches. As a statement, their values are ignored.
- **No match** traps with kind `"match"`. Add `_:` to handle the rest.

## Functions, closures and overloading

Functions are first-class, and any function can be called as a method on its first argument. Parameters can have defaults and arguments can be named. Any name can be overloaded, by number of parameters or by annotated parameter types.

**Closures**

- Lambdas are `|x| x + 1` and `|a, b| a + b`. A braced body, `|x| { ... }`, uses `return`, the same rule as a braced `fn`. They capture variables by reference.
- **Implicit `it`.** A call argument that uses `it` without defining it is a one-parameter lambda, as in Nim's `mapIt`: `nums.map(it * 2)`, `edges.filter(it.w > 3)`, `words.sort_by(it.len())`. `it` means the innermost such argument, so use `|x|` to reach an outer one. Lambdas with two or more parameters use `|a, b|`.
- They compile by closure conversion: an environment struct plus a function pointer, inlined when the closure does not escape.
- Record fields may hold closures, but this is discouraged: such records cannot be hashed, compared or passed to C.

**Uniform call syntax.** `x.f(y)` is sugar for `f(x, y)`. The compiler tries a field named `f` first, then a free function. Any library function over a graph therefore becomes a graph method with no extra declaration.

**Default and named arguments.** `fn f(a, k = 1)` gives `k` a default, and a caller can name any argument after the positional ones: `heap(key: -it)`, `t.show(label: |v| "{v}")`. The library relies on this for optional arguments such as `read_ints()` without a count.

**Shortened names.** An argument or field name can be any prefix that picks out exactly one candidate, so nobody has to remember whether it was `address` or `addr`:

```
fn f(age, address, name) = ...
f(12, "Main St", "john")              // positional
f(address: "Main St", name: "john", age: 12)  // named, in any order
f(ad: "Main St", ag: 12, n: "john")   // shortened
pp(state, ind: 4, l: Many)

record Box(width, height)
b.wi * b.he                           // b.width * b.height
```

- An exact name always wins, so a field `n` beside `name` is still reachable as `n`.
- A prefix that fits two names is a compile error that lists them: `a:` could be `age` or `address`.
- This covers named arguments, record and variant construction, `.with()`, pattern fields and field access with `.`. It does not cover variables, functions or types, which are always written in full.
- Field access is resolved after the type is known, so in a generic `fn area(s) = s.w * s.h`, `.w` may mean `w` for one record type and `width` for another.
- Adding a field or parameter can make an old prefix ambiguous. The error then names both candidates, which is a fair trade for code that is written once.
- Named arguments use `:`, not Python's `=`, so a printed record like `Point(x: 1, y: 2)` is also valid code.

**Variadic functions.** `..` before the last parameter collects the remaining arguments into an array, the same `..` that means "the rest" in patterns. `..` before an argument spreads an array into the call. All the collected arguments share one type, since arrays are homogeneous.

```
fn min(first, ..rest) = rest.fold(first, |a, b| if b < a { b } else { a })
min(3, 1, 2)
min(..xs)
```

`print` and the typed readers `read(...)` and `read_rows(...)` take arguments of mixed types, or types as arguments, so they are compiler built-ins rather than library functions.

**Overloading.** Any function, operator or hook can have several definitions. They are told apart by number of parameters or by annotated parameter types, and an unannotated parameter matches anything. This is what lets the library define `show` for grids, trees and graphs, and `min(a, b)` next to `xs.min()`.

```
record Point(x, y)

fn ==(a: Point, b: Point) = a.x == b.x and a.y == b.y
fn +(a: Point, b: Point) = Point(a.x + b.x, a.y + b.y)
fn str(p: Point) = "<{p.x}, {p.y}>"
fn *(a: Vec, b: int) = ...
fn *(a: int, b: Vec) = ...    // 2 * v is its own definition
```

- Dispatch looks at all annotated parameters, so mixed types need one annotation per parameter. The most specific match wins, and two equally specific matches are an error.
- No implicit conversion applies to user-defined overloads, and builtin numeric widening stays in the builtin table.
- A fully annotated body is checked at its definition. Unannotated parameters keep it generic, checked at instantiation.
- Two definitions that could accept the same call equally well are an error at the second definition, and that includes parameter counts that overlap through defaults. A literal argument that fits more than one overload, such as `f(1)` with `f(x: int)` and `f(x: float)`, takes its default type.
- Overloadable operators are `+ - * / // % ** @ ==` and unary `-`. The hooks `cmp`, `hash` and `str` customize derived behavior.
- `==`, `hash` and `cmp` are derived structurally. Overriding `==` without `hash` is an error. `cmp(a, b)` returns negative, zero or positive and derives `< > <= >=`, `sort` and priority queue ordering.
- `str` controls both `print(p)` and `"{p}"`, and containers call it on their elements.

**Memoization.** A `memo` modifier before `fn` caches results by arguments, which covers most dynamic programming. The cache does not see globals the function reads, so with several test cases call `f.clear()` before each one.

## Imports

A program can import other source files, mainly so Advent of Code days can share parsing and grid helpers and so a personal library of templates can be reused. There are no packages, no `__init__` files and no manifest: a module is one file, and a folder is only part of a path.

```
import geom                 // geom.cp next to this file
import aoc.parse            // aoc/parse.cp; the module is named parse
import aoc.parse as p       // rename
import grid2.*              // everything in grid2, unqualified
import aoc.input.{lines, ints}  // just these names, unqualified

pts = read_lines().map(parse.point)
print(geom.dist(pts[0], pts[1]))
a = geom.Point(1, 2)
b = a + geom.Point(3, 4)    // geom's + on Point, found without a prefix
print(a.dist(b))            // geom's dist, found through Point's module
```

**Lookup.** `import a.b` loads `a/b.cp` relative to the importing file. If it is not there, the compiler looks in one user library folder, set by an environment variable, so personal templates are available from any day's folder. The `.cp` extension is a placeholder until the language has a name.

**The standard library is always in scope.** Every library name is available unqualified with no import, as if star-imported.

**Your modules are accessed with a dot.** `import geom` binds the name `geom`, and its contents are reached as `geom.dist`, `geom.Point` and so on.

**Selectors pick what comes in unqualified.** Whatever follows the module path says what to take, so there is one keyword and it reads left to right:

- `import geom.*` brings every name in `geom` into scope unqualified.
- `import geom.{dist, Point}` brings in just those names.
- Both forms still bind `geom`, so `geom.dist` keeps working.
- `.*` and `.{...}` can only end a path, so `import a.b.*` is fine and `import a.*.b` is a syntax error.
- If two imports bring in the same name, they merge as overloads when their parameter types differ. A call that matches both equally is a compile error naming both modules, and a prefix like `geom.dist` resolves it.

**Calls found through the type.** Uniform call syntax and operators would be useless on types from a plain `import` if they only saw unqualified names, so they also look in the module that defined each argument's type:

- `x.f(y)` tries a field `f`, then `f` in scope, then `f` in the module that defined the type of `x`.
- An operator or hook (`+`, `==`, `cmp`, `hash`, `str` and the rest) on a record or variant also looks in the module that defined it, so `a + b`, `print(p)` and sorting work on `geom.Point` without a prefix.
- Plain calls like `dist(a, b)` and calls on builtin types like `5.sq()` do not do this; write `geom.dist(a, b)` and `geom.sq(5)`.

**Shadowing is silent.** A name defined in your file hides a library or imported name with no warning, and a local variable can hide a module name. Two details:

- A definition with the same parameter types replaces the library's version. One with different parameter types adds an overload, so defining `fn min(a: Point, b: Point)` leaves `min(3, 4)` working.
- Shadowing only affects the file that does it. Library code and other modules keep calling their own definitions, so defining your own `find` does not break `dsu`.

**What an imported file may contain.**

- Anything a program may contain. Its top-level statements run once, before the importer's, in the order imports are first reached. That is how a module sets constants such as `DIRS` or a precomputed table.
- Its globals belong to it and are reached as `geom.EPS`.
- `#in` and `#out` blocks are ignored on import but still run when the file itself is tested, so a library file can carry its own tests.
- Program-level pragmas such as `#default int = big` and `#pp` belong only to the main file and are an error elsewhere. Library code is generic over the `int` alias, so it follows the main file's choice.
- Cyclic imports are an error.

**Cost.** Only functions that are called get compiled, so importing a large helper file costs nothing at runtime. Unannotated functions are checked where they are used, so an error inside an imported function shows the call site in your file and the chain of imports.

## Iterators and chaining

Every collection and range supports method chaining, so a pipeline reads left to right as the data flows.

```
best = read_lines()
  .map(|l| l.extract_ints().sum())
  .filter(|s| s > 0)
  .sort(desc: true)
  .take(3)
  .sum()
```

- **Sources:** arrays, strings, sets, maps (as key-value pairs), ranges, open ranges such as `0..`, and `(0..n).step(2)`.
- **Transform:** `map`, `filter`, `flat_map`, `zip`, `enumerate`, `take`, `skip`, `take_while`, `windows(k)`, `chunks(k)`, `reverse`, `sort`, `sort_by(key)`, `unique`, `scan(init, f)` (running totals, so prefix sums are `a.scan(0, +)`), `pairs()` (every `i < j` pair), `combinations(k)` and `permutations()`.
- **Reduce:** `sum`, `product`, `min`, `max`, `min_by`, `max_by`, `count`, `any`, `all`, `find`, `position`, `fold`, `reduce`, `join`. `find` and `position` return optionals, `sum` of nothing is `0`, and `min` or `max` of nothing traps.
- **Collect:** `to_array`, `to_set`, `to_map`, `counter()` (a map from element to count) and `group_by(key)`.
- **Lazy and eager.** A chain that starts from a range is lazy, so `(1..).filter(is_prime).take(3)` stops after three. A chain that starts from a collection is eager and each stage returns an array, so `xs.map(f)[0]` works. This is Kotlin's split between collections and sequences.
- **Fusion.** A later optimization pass fuses visible `.map().filter().sum()` chains into one loop. It only fuses lambdas that do no I/O and assign to no captured variable, so it never changes what a program prints.
- Lambda parameter types come from the receiver, so chains need no annotations.
- **Chains replace nested calls.** Every function works in chain position, `print` included, so `print(sum(set(xs)))` is `xs.to_set().sum().print()`. Adding a step means typing `.f()` at the end instead of jumping back to wrap the line in parentheses. There is no pipe or composition operator; `|x| f(g(x))` composes when a function value is needed.

## Input and output

All input functions share the `read_` prefix, so there is one family to remember. Input is read in one buffered gulp and parsed from memory, which keeps it fast.

| Function | Returns | Meaning |
| --- | --- | --- |
| `read_int()` | `int` | Next whitespace-separated token as an integer |
| `read_float()` | `float` | Next token as a float |
| `read_word()` | `str` | Next token as a string |
| `read_line()` | `str` | Next line, without the newline |
| `read_ints(n)` | `[int]` | Next `n` integers; with no `n`, the rest of the current line |
| `read_floats(n)` | `[float]` | Same, for floats |
| `read_words(n)` | `[str]` | Same, for words |
| `read_lines(n)` | `[str]` | Next `n` lines; with no `n`, all remaining lines |
| `read_all()` | `str` | Everything left in the input |
| `read(int, float, str)` | `(int, float, str)` | One typed tuple from the next tokens |
| `read_rows(n, int, int, int)` | `[(int, int, int)]` | `n` rows of typed tuples, such as edge lists |
| `read_grid()` | `[[u8]]` | All remaining lines as a mutable byte grid |
| `read_blocks()` | `[[str]]` | All remaining lines, split into groups at blank lines |
| `read_eof()` | `bool` | True when no input remains |

```
n = read_int()
a = read_ints(n)
(u, v, w) = read(int, int, int)
edges = read_rows(m, int, int, int)
cells = read_line().split(",").map(int)
x: big = read_int()
r: rat = read_float()
bs: [big] = read_ints(n)
```

- **Numeric types come from context.** `read_int()` and `read_ints(n)` return any integer type (`int`, `u8`, `big`, `Mod(m)`), and `read_float()` returns any fractional type (`float`, `rat`, `bigfloat`). Inference picks the type from a declared type or later use, and falls back to the program default. The Returns column above shows the defaults, where `int` means whatever `int` currently is: `i64`, or `big` under `#default int = big`. A `rat` is read exactly from decimals such as `1.25` or fractions such as `3/4`.
- Token readers skip any whitespace, including newlines. `read_line()` returns the rest of the current line if it has text. If only whitespace remains after a token read, it first consumes that remainder and returns the following line, which avoids the classic Java mix-up of `nextInt` followed by `nextLine`.
- A custom delimiter uses string methods: `read_line().split(sep)`, or `s.extract_ints()` to pull every integer out of any string.
- Reading past the end of input traps; test with `read_eof()`.

**Output.** `print(a, b)` writes its arguments separated by spaces plus a newline, `put(x)` writes without a newline, and output is buffered and flushed at exit. `flush()` is available for interactive problems. `eprint`, `dbg` and `pp` write to stderr; see Printing and debugging.

## Standard library

Graphs, trees, matrices and algorithms are library code written in the language itself, not compiler features. Uniform call syntax turns each function into a method, and only the functions a program calls are compiled, so the library can grow without slowing compilation or touching the compiler.

| Area | Examples |
| --- | --- |
| Graphs | `graph(n)`, `g.edge(u, v, w)`, `g.arc(u, v)`, `g.bfs(s)`, `g.dijkstra(s)`, `g.topo_sort()`, `g.components()`, `g.bridges()`, `g.show()`, `g.dot()`; weights are generic over `int` and `float` |
| Trees | `tree(n)`, parent and depth arrays, Euler tour, LCA, `t.show()`, `show_tree(root, kids)` |
| Data structures | `dsu(n)` with `find` and `union`, Fenwick tree, segment tree, monotonic stack |
| Grids | `grid(n, m, v)`, `g[p]` and `g.inside(p)` for a pair `p`, `neighbors4(p)`, `neighbors8(p)`, `manhattan(p, q)`, find a value, `g.show()` |
| Search | `bsearch`, `lower_bound`, `upper_bound` |
| Math | `min(a, b, ...)`, `max`, `abs`, `gcd`, `lcm`, `ceil_div`, `isqrt` (exact), `popcount`, `bit_length`, `pow_mod`, sieve, factorials and binomials |
| Strings | prefix function, Z function, rolling hash |
| Matrices | `A @ B`, `A ** k`, `A \ b` (solve), `det`, `inv`, `transpose`; exact solving over `rat` |

- Matrix syntax needs operator support in the checker: `@` for multiply, `**` for power (needed for modular Fibonacci-style problems) and `\` for solve. The builtin cases are hardcoded; user-defined versions use the overload hooks.
- Linear solving starts as hand-written LU with partial pivoting, about 50 lines, not LAPACK.
- A library test file calls every function at least once, because generic code is only checked when instantiated.
- Trees stored as parent and child index arrays remain the fast default; a recursive `record Node` suits parsed or expression trees.

## Sample tests

A program can carry the examples from the problem statement as plain text, pasted with no quotes or escapes. The compiler's `test` command runs the program on each one and compares its output.

```
#in
3
1 2 3

#out
6

#in samples/3.in      // from files, relative to the source file
#out samples/3.out

#in input.txt         // no #out: just run it and show the output
```

- **Directives are whole lines.** A line counts only if it is exactly `#in`, `#out` or `#end`, optionally followed by a file path. Advent of Code grids often start lines with `#`, and `#..#.` is still data.
- **A block** is the lines between its directive and the next directive or the end of the file. Tests usually go at the bottom; if code follows them, close with `#end`.
- **Blank lines at the start and end of a block never count,** so blocks can be spaced out freely. The program's input always ends with exactly one newline.
- **Output is compared line by line,** ignoring trailing spaces on each line and trailing blank lines. Blank lines in the middle are kept and compared.
- A directive line may end with a `//` comment. Inside a block, `//` is data.
- An `#in` with no `#out` just runs, which suits a real Advent of Code input with no known answer.
- A normal run ignores these blocks, so the file submits unchanged. `#` directives are the same family as `#pp` and `#default`, so `test` is not a reserved word.
- Output written with `dbg`, `pp` and `eprint` goes to stderr and is shown but not compared.

## Memory, FFI and concurrency

Memory is managed automatically, and the v1 runtime never frees. Short-lived contest programs rarely run long enough for that to matter, and a better collector can be swapped in later without changing the language.

**Memory**

- v1: a bump allocator that never frees.
- Later options: Boehm GC or reference counting. Neither changes language semantics.
- Value and reference rules are in the tuples, named tuples and records section.

**C FFI.** Declared with `extern fn`, where annotations are required.

```
extern fn strlen(s: str) -> int
extern fn sqrt(x: float) -> float
```

| Language type | C side | Status |
| --- | --- | --- |
| `int`, `i8` to `u64`, `float` | Matching C integer and double types | v1 |
| `str` | NUL-terminated `char*` | v1; see below |
| Array `[T]` | `T*` plus length | v1 |
| Record, or named tuple by pointer | `struct*` | v1 |
| Named tuple by value | C struct passed by value | Later; needs C ABI classification, which clang normally does for you |
| `big` | GMP's `mpz_t` layout, passed by pointer | v1 |

**Strings at the boundary.** There is no separate C string type. A `str` is bytes plus a length with no terminator, and a slice shares memory with its source, so passing a `str` to an `extern fn` passes a NUL-terminated copy, and a `char*` returned as `str` is copied up to its NUL. The never-free arena makes the copies harmless. A string that contains a `\0` byte would be cut short in C, so passing one traps.

**Concurrency.** Out of scope for v1. The most useful later addition is `par_map`, which takes a closure that captures only immutable data. A never-free arena keeps threads simple; a garbage collector would make them harder.

## Compiler architecture

The compiler is a short pipeline that emits textual LLVM IR and lets `clang` finish the job.

&#91;embedded content: compiler pipeline · 7 stages plus the C runtime\]

Read the top row left to right, then the bottom row right to left. The C runtime is compiled once and linked in.

**Choices**

- **Implementation language:** Rust using only `std` is the recommended path, since enums and `match` suit ASTs and type passes. C works too, with an arena allocator that never frees.
- **LLVM:** emit `.ll` text and call `clang`. No bindings are needed, and the output is readable when debugging.
- **Runtime in C:** hash map, fast stdin, the allocator and `setjmp`-based `try`, plus GMP for big numbers.
- **Lowering:** mutable variables use `alloca` and LLVM's `mem2reg` builds SSA; closures use environment structs; trapping arithmetic uses overflow intrinsics.

**Milestones**

1. Ints, floats, functions, control flow, arrays and strings.
2. Inference with implicit generics and monomorphization.
3. Tuples, records, variant types and `match`, closures, maps, sets, uniform call syntax, optionals and `try`/`catch`.
4. The `read_` family, buffered output, formatting and derived printing, `dbg` and `pp`.
5. The library in the language itself: iterators, graphs, grids and data structures.
6. `big`, `Mod`, `rat`, matrices and the solver.
7. FFI, then iterator fusion, then threads if wanted.

## Open questions

These decisions are still open, and each can change the compiler's design.

- **Language name.** The language is still unnamed, which also leaves the source file extension open.
- **Imports.** Whether names starting with `_` should be private to their module. Whether a `bundle` command that inlines imports into one file is needed if submitting to online judges ever matters.
- **Before any compiler code,** rewrite 10 to 15 real contest and Advent of Code solutions in this syntax and note where it feels clumsy.
