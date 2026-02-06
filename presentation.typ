#import "presentation-template.typ": *
#import "header.typ": *

#let a-stack = text(weight: "bold")[A] + [ stack]
#let b-stack = text(weight: "bold")[B] + [ stack]
#let c-stack = text(weight: "bold")[C] + [ stack]

#let overview-path(..parts, active: ()) = {
  if type(active) == int { active = (active,) }

  place(top + right,
    for (i, part) in parts.pos().enumerate() {
      if i > 0 { context text(size: 16pt, fill: text.fill.transparentize(50%))[ #sym.arrow ] }
      context text(size: 16pt, fill: if i + 1 in active { text.fill } else { text.fill.transparentize(50%) }, part)
    }
  )
}

#show: presentation.with(show-notes: none, dark: true)

#let clean-coloured = text.with(fill: red.lighten(50%))
#let abc-coloured = text.with(fill: orange.lighten(50%))
#let llvm-coloured = text.with(fill: green.lighten(50%))
#let wasm-coloured = text.with(fill: rgb("654ff0").lighten(50%))

#let bench = (
  heap-64k: (
    list: load-benchmark("benchmark/64kiB/list_large.csv"),
    astack: load-benchmark("benchmark/64kiB/astack_mult.csv"),
  ),
  heap-16M: (
    list: load-benchmark("benchmark/16MiB/list_large.csv"),
    astack: load-benchmark("benchmark/16MiB/astack_mult.csv"),
    binarytrees: load-benchmark("benchmark/16MiB/binarytrees.csv"),
  ),
)

= Quick Clean for the Web <touying:hidden>
#title-slide[
  #text(weight: "bold", size: 1.2em)[Dante van Gemert] \
  #text(weight: "thin")[Thursday 5#super[th] February 2026]

  #speaker-note[
    *Questions?* Just raise hand
  ]
]

= Introduction <touying:hidden>

== Web is where it's at
E-mail, Google Docs, Typst, custom keyboard software, ...

#v(1em)
But: JavaScript #em(emoji.face.teeth)

#speaker-note[
  - You probably realise this.
    *E-mail*: web app.
    *Calendar*: web app.
    Fancy weird customisable *keyboard* that consists of two separate parts and has a weird key layout: web app for customisation.
  
    So we want to make a web app, too!
  
    *But* that means writing JavaScript, right? Nobody really likes JavaScript.
]

== #clean-coloured[Clean]
#slide(composer: (10fr, 8fr))[
  Functional programming language
  
  #pause
  
  === iTasks
  - Structure code with tasks
  - Automagically generates web #ui #em(emoji.sparkles)
  #pause
  - Program runs on server
  - Small bits of Clean code in browser for creating #ui elements
  #pause
  - Beneficial to run more in browser
    - Reduce latency, increase availability
  
  #pause
  
  But: interpreting is too slow
  
  #speaker-note[
    - We would *much rather use Clean*, the functional language developed here at Radboud.
  
    - Luckily, Clean has a nice framework for structuring code projects with tasks, which automagically generates a *web-based user interface*.
  
    - While the program itself runs on a *server*, there are small bits of Clean code that run in the *browser*. These actually create the #ui elements.
  
    - Those who were here for the previous presentation know that it would be good to run *more in the browser*.
  
    - *But* the #abc interpreter that is used for running Clean in the browser then becomes *too slow*.
  ]
][
  #figure(
    caption: [VIIA],
    numbering: none,
    image("img/viia.png", height: 80%)
  )
]

= Compilation Pipeline <touying:hidden>

== Clean-LLVM
#overview-path(active: 1)[#clean-coloured[Clean]][?]

Compile instead of interpret

#pause

=== In short
- Clean web-app #sym.arrow iTasks
- Better performance #sym.arrow #clean-llvm (instead of #abc interpreter)

#pause

#v(1em)
But: don't want to compile Clean code directly

#speaker-note[
  - The *solution*, then, is to *compile* instead of *interpreting*.

  - In short:
    - We want to create a *web app* with Clean, for which we can use *iTasks*.
    - Now we want *better performance*, for which we use *#clean-llvm*.

    I've put Clean and an arrow to a question mark in the corner, to keep track of the process of compiling Clean for the web.

  - To start, we *don't want to completely re-implement* the Clean compiler.
]

== #abc-coloured[ABC]
#overview-path(active: 2)[#clean-coloured[Clean]][#abc-coloured(abc)][?]

Use Clean compiler's #abc bytecode

#figure(include "diagrams/compilation-overview-simple-no-clean-llvm.typ")

What do we compile *to*?

#speaker-note[
  - Luckily, the Clean compiler outputs its intermediate code called *#abc code*.
]

== #wasm-coloured[WebAssembly (Wasm)]
#overview-path(active: 4)[#clean-coloured[Clean]][#abc-coloured(abc)][?][#wasm-coloured[WebAssembly]]

- Compilation target for the web
- Stack based
- Safe & secure (#sym.arrow restrictive)
- C(++), Rust, Go, Kotlin, Dart, ...

#pause
#v(1em)
Originally focussed on imperative languages
- Recently: tail calls

#pause
#v(1em)
But: we can do better than generating Wasm directly

#speaker-note[
  - We compile to *WebAssembly*, which is the compilation target for the web. It makes it possible to use any language other than JavaScript for the web, without explicit browser support.

    It is a *stack based* language, focussed on *safety / security*. This does make it quite *restrictive*, though.

    There are several languages that have a WebAssembly target. As you can see, all the hip and cool languages are compiling to Wasm! And C is also there.

  - Wasm originally focussed on supporting imperative languages, but recently started supporting functional languages, by implementing tail calls.

  - But we can do better than generating Wasm directly. 
]

== #text(fill: green.lighten(50%))[LLVM]
#overview-path(active: 3)[#clean-coloured[Clean]][#abc-coloured(abc)][#llvm-coloured(llvm)][#wasm-coloured[WebAssembly]]

- Compiler toolkit
- Clang compiler for C & C++
- Intermediate representation (#ir)
- Optimisation passes (inlining, dead code elimination, ...)
- Rust, Zig, Julia, Swift, ...

#pause
=== Why?
- Generates Wasm, but also x86, Arm, #smallcaps[risc-v]...
- Optimisations

#pause
#v(1em)
Wasm is not a standard target for #llvm
- Requires some creative solutions

#speaker-note[
  - Instead, we use *#llvm*, which is a *compiler toolkit* containing the Clang C(++) compiler, optimisations, an intermediate representation, and more.

    The optimisations work in *passes*, so each optimisation pass works on the output of the previous. This makes it easily extendable with custom passes.

    These are some languages that use #llvm for their code generation.

  - We use #llvm, because it generates Wasm code *and* it creates executables for x86, #arm, #smallcaps[risc-v], ... Additionally, it also further optimises the code.

  - Wasm is a special target for #llvm: not everything is possible, since it's so restrictive.
]

== Overview
#figure(include "diagrams/compilation-overview-simple.typ")

#pause
#v(1em)
Focus on WebAssembly

#speaker-note[
  #todo[nog even terugkomen op algemeen overview / waarom?]

  - Now let's return to the overview from before. Starting from #abc code, we generate #llvm #ir. We pass that to Clang, which then generates the output we want.

  - Let's *focus on WebAssembly* for the rest of the presentation, though.

    Now this is great, but it isn't *fast enough*. But before we can look at the *optimisations*, we first need to go over the integration of the *garbage collector*.
]

= GC Integration //<touying:hidden>

#speaker-note[
  Since Clean is a functional language, it needs a #gc. #clean-llvm uses the #gc from the #abc interpreter. Integrating this #gc is something I did in my internship.

  The #gc needs to know which values are on the heap.
]

== Heap and A Stack
#a-stack: references to the heap (boxed values) \
#b-stack: basic values (unboxed values: int, char, bool, ...) \
#c-stack: control flow

(hence the name of #abc code)

#v(1em)
#figure(
  caption: [Creation of the list `[1]`.],
  numbering: none,
  include "diagrams/astack-singleton.typ"
)

#speaker-note[
  - Luckily, Clean places all heap references on one stack: the *#a-stack*.
]

== GC Integration
- #a-stack is on WebAssembly stack, for performance
- Can only access stack frame of current function

#pause

=== Shadow stack
+ *Spill* (write #a-stack to memory)
+ *Restore* (read back new addresses)

#pause

=== LLVM passes
- Run optimisations before generating spills/restores: inlining, dead code elimination
- Leads to less function calls #sym.arrow less spill locations

#speaker-note[
  - The #gc needs to have *access* to the #a-stack to find the active heap values. But the #a-stack is on the WebAssembly stack, and we cannot look outside the stack frame of our function.

  - To solve this, *we also write the #a-stack to memory*, where the #gc can access it. But the #gc also *moves things around* on the heap, so after garbage collection we need to *read the new addresses back*. This mechanism is called a *shadow stack*.

    // We manage this shadow stack around function calls, since those are the moments where #gc might happen. Just before, we *spill*. Right after, we *restore*.

  - We create this shadow stack using multiple #llvm passes. We do this later instead of immediately in Clean because we can run some #llvm optimisation passes before generating spill/restore code.

    Inlining leads to *less function calls*, which means less places to spill.
    // We use #llvm's support for integrating a #gc because it makes it more performant for native targets.
]

== Shadow Stack Overview
#overview-path[mark][statepoints][`asp` arg][spill]

+ Mark A stack (preparation)

+ Insert statepoints

+ Add shadow stack argument

+ Add spills

#speaker-note[
  - How do we generate code to keep track of this shadow stack?

    + We mark values that are on the A stack with a special type.
    + Then we insert statepoints, which are an #llvm feature.
    + We also add a function argument pointing to the shadow stack.
    + Lastly we take all this and we generate the actual spill/restore instructions.
]

#let highlight-code(it) = text(weight: "black", underline(offset: 0.2em, evade: false, stroke: 2pt, it))

#show "@f": highlight-code
#show "@f_asp": highlight-code
#show "42": highlight-code
#show regex("%a\b"): highlight-code
// #show regex("%a.new\b"): highlight-code
// #show "%answer": highlight-code

== Preparation: Mark A Stack
#overview-path(active: 1)[mark][statepoints][`asp` arg][spill]

- Which #llvm variables are on #a-stack?
- Mark them with special type

#pause

#enum(start: 1)[Mark heap references (#a-stack values)]

#v(1em)
#grid(columns: (auto, auto, auto), gutter: 2em,
  ```llvm
  ptr %a
  ```,
  align(center, sym.arrow),
  ```llvm
  heapptr %a
  ```
)

#v(1em)
Note: simplified / imaginary syntax

#speaker-note[
  - Firstly, the #llvm passes need to know which #llvm variables are on the #a-stack. So, we *mark those* in #llvm code with a *special type*, to distinguish them from other pointers.

    Note: simplified / imaginary syntax
]

== LLVM Pass: Insert Statepoints
#overview-path(active: 2)[mark][statepoints][`asp` arg][spill]

- Statepoint: point at which #gc _can_ run
- Only need to update spilled #a-stack across statepoints
  - spill before, restore after

#pause

#enum(start: 2)[Convert function calls to statepoints]

#v(1em)
```llvm
%answer = call i64 @f(42)
```

#pause
#sym.arrow.b

```llvm
%s = call token @gc.statepoint(@f, 42) [ "gc-live"(heapptr %a) ]
```
#pause
```llvm
%answer = call i64 @gc.result(%s)
```
#pause
```llvm
%a.new = call i64 @gc.relocate(%s, 0)
```

#speaker-note[
  - Now we're in the land of #llvm passes. We use an #llvm feature called *statepoints*. This is a *point in the execution* of the program where the #gc can run, and so where *pointers can change*. We only need to spill and restore across statepoints. Because, if the #gc doesn't run, there is no need to keep the shadow stack up to date. This is why it's good to *inline before*.

  - So let's say we call a function `@f` with the integer `42` as argument. We transform it into a statepoint by calling the `gc.statepoint` function/intrinsic (not really a function). We pass it the *function itself* and the *arguments*.

    We also attach all values on the *#a-stack of the current function*, which we marked in the previous step. The actual return value comes from `gc.result`.

    If we use `%a` later on, we must use `%a.new` instead. (`0` = the first value)
]

== LLVM Pass: Add Stack Top Argument
#overview-path(active: 3)[mark][statepoints][`asp` arg][spill]

#enum(start: 3)[Add argument for pointer to spilled #a-stack]
  - `asp` = *A* *S*\tack *P*\ointer

#v(1em)
```llvm
define i64 @f(i64 %x)
```

#sym.arrow.b

```llvm
define { ptr, i64 } @f_asp(ptr %asp, i64 %x)
```

#speaker-note[
  - Since we need to spill to the shadow stack, we need to know where the *top of the stack* is. For this, we add a pointer to every function call and return.

    Every function gets an extra parameter and return value. In practice, we add a new function with the right signature and copy over the function body.
]

== LLVM Pass: Add Spills
#overview-path(active: 4)[mark][statepoints][`asp` arg][spill]

#enum(start: 4)[Transform statepoints to function calls, spills, restores]

#only("1-2")[
  #v(1em)
  ```llvm
  %s = call token @gc.statepoint(@f, 42) [ "gc-live"(heapptr %a) ]
  ```
  ```llvm
  %answer = call i64 @gc.result(%s)
  ```
]
#only(2)[
  #sym.arrow.b
  
  ```llvm
  store %a to %asp ; spill
  ```
  ```llvm
  { %asp.new, %answer } = call i64 @f_asp(%asp, 42)
  ```
]

#only(3)[
  #v(1em)
  ```llvm
  %a.new = call i64 @gc.relocate(%s, 0)
  ```
  
  #sym.arrow.b
  
  ```llvm
  %a.new = load %asp.new ; restore
  ```
]

#speaker-note[
  - Now we take these statepoints, and we transform them back to function calls. These are the two lines of code from two slides back.

  - First spill every value in `"gc-live"`, then call the function.

  - We also still have these `gc.relocate` calls, which become restores.
]

== LLVM Passes: All Together
#overview-path(active: (1,2,3,4))[mark][statepoints][`asp` arg][spill]

```llvm
%answer = call i64 @f(42)
```

#sym.arrow.b

```llvm
store %a to %asp ; spill
```
```llvm
{ %asp.new, %answer } = call i64 @f_asp(%asp, 42)
```
```llvm
%a.new = load %asp.new ; restore
```

#pause
#v(1em)
=== Why statepoints?
Implementation for native x86 without shadow stack #text(fill: luma(50%))[(theoretically)]

#speaker-note[
  - You may ask: "what are you doing? Why generate statepoints only to remove them again later?"

    There's a more efficient implementation possible with statepoints, which does not need a shadow stack. This doesn't work for Wasm, though. (Restrictive!)
]

#let barplot(bm, columns,
  title: none,
  max: auto,
  width: 8cm,
  height: 7cm,
  label-angle: -25deg,
  cycle: (red, (colour: green, hatch: hatched), (colour: blue, hatch: dotted))
) = {
  let runs = columns.map(group => group.map(name => bm.at(name)))
  let means = runs.map(group => group.map(it => mean(it)))

  context {
    let offset = 0
    lilaq.diagram(
      width: width,
      height: height,
      xaxis: (
        ticks: columns.flatten()
          .map(align.with(right))
          .map(box.with(width: 0pt))
          .map(rotate.with(label-angle, reflow: true))
          .enumerate(),
        ),
      ylabel: "run time (ms)",
      ylim: (0, max),
      title: title,
      ..for (i, group) in columns.enumerate() {
        let positions = range(offset, offset + group.len())
        
        let mean = means.at(i)
        let colour = unpack(cycle.at(i), "colour", type: color)
        let (fill, stroke) = cell-colour(colour, width: 1.5pt)
        let hatch = unpack(cycle.at(i), "hatch")
        fill = if hatch == none { fill } else { hatch(fill: fill, stroke: stroke, scale: 15pt) }
        let plots = (
          lilaq.bar(positions, mean, fill: fill, stroke: stroke),
          lilaq.plot(
            positions,
            mean,
            yerr: runs.at(i).map(it => stddev(it)),
            stroke: none,
            color: text.fill,
          ),
        )
        offset += group.len()
        plots
      }
    )
  }
}

= Results

== Benchmarks
Restriction: not all #abc instructions implemented yet

#pause
#v(1em)
- List
  - Create a long list and sum it
- Astack
  - Create 16 heap nodes and pass them to multiple function calls
- *Binarytrees*
  - From the Computer Language Benchmark Game
  - Required additional #abc instructions

#speaker-note[
  - The time has come to evaluate the performance. I ran three benchmarks with varying degrees of 'real'-ness.

    It's hard to get more complex benchmarks to run, because of the limited set of #abc instructions implemented.

  - I only display the results of *binarytrees*, since it is the *most realistic* benchmark.
]

== Benchmark: Binarytrees
Wasm: 7 times faster than #abc interpreter (#num(mean(bench.heap-16M.binarytrees.interpreter) / 1000, digits: 1, unit: "s") vs #num(mean(bench.heap-16M.binarytrees.at("wasm+pass")) / 1000, digits: 1, unit: "s"))

#align(center, barplot(bench.heap-16M.binarytrees, (("interpreter",), ("wasm+pass",)), cycle: (purple, blue)))

#speaker-note[
  Let's look at the results! First compare the #abc interpreter with our Wasm output, which is the use case I described at the start. Both of these are running on the same platform (Node.js / V8).

  The interpreter takes *#num(mean(bench.heap-16M.binarytrees.interpreter) / 1000, digits: 1, unit: "s")*. \
  Our Wasm output takes *#num(mean(bench.heap-16M.binarytrees.at("wasm+pass")) / 1000, digits: 1, unit: "s")*.

  Our generated Wasm code is *7 times faster* than the #abc interpreter, so that's promising.

  This is expected, though: of course compilation is faster than interpretation.
]

== Benchmark: Binarytrees
Close to original Clean compiler's performance

#align(center, barplot(bench.heap-16M.binarytrees, (("baseline",), ("llvm+pass",), ("wasm+pass",)), cycle: (red, green, blue)))

#speaker-note[
  We can also compare to the original Clean compiler, running natively on x86. "llvm+pass" is our #llvm output running natively on x86, as opposed to "wasm+pass" which runs in Node.js / V8.

  Our generated x86 / Wasm code is *slightly slower* than baseline for this program.

  ...

  Do you see what that means? It means that it is about as fast to run this "binarytrees" benchmark *in the browser* with our Wasm output, as it is to run it as a native x86 executable.

  We're comparing apples to oranges, but in this case they're each about as tasty.
]

== Conclusion
- *Why?* More client-side iTasks code #sym.arrow interpreter too slow
#pause
- #clean-coloured[Clean] #sym.arrow #abc-coloured(abc) #sym.arrow #llvm-coloured(llvm) #sym.arrow #wasm-coloured[WebAssembly]
#pause
- *#gc integration* with shadow #a-stack: spill/restore
#pause
- *#llvm passes* with statepoints
  + Mark #a-stack #text(fill: luma(50%))[(not a pass, but preparation)]
  + Convert function calls to statepoints
  + Add shadow #a-stack pointer argument
  + Convert statepoints to spills/restores
#pause
- *Optimisation:* inlining before generating statepoints
#pause
- *Results:* 7 times faster than interpreter, close to original Clean

#pause
*Future work:* statepoints without shadow stack for native x86

= Extra Slides

== Optimisation: Static Nodes
#figure(include "diagrams/static-nodes.typ")

#speaker-note[
  - This optimisation is meant to reduce the number of things on the heap.

    Nodes that have no arguments are *stored statically*, since there is logically only ever one of them: nil is nil, there are no other nils.

    Instead of re-creating the same nil node on the heap every time, we *re-use the static one*. The original Clean compiler also does this.
]

== More Benchmarks: Binarytrees
#align(center, barplot(bench.heap-16M.binarytrees, (("baseline",), ("llvm", "llvm+static", "llvm+alias", "llvm+lazy", "llvm+pass",), ("wasm", "wasm+static", "wasm+alias", "wasm+lazy", "wasm+pass",)), width: 16cm, height: 8cm, label-angle: -60deg, cycle: (red, green, blue)))

== More Benchmarks: Astack
#slide[
  #set text(size: 0.9em)
  #align(center, barplot(bench.heap-64k.astack, (("baseline",), ("llvm", "llvm+static", "llvm+alias", "llvm+lazy", "llvm+pass",), ("wasm", "wasm+static", "wasm+alias", "wasm+lazy", "wasm+pass",)), width: 10cm, height: 8cm, label-angle: -70deg, cycle: (red, green, blue)))
][
  #set text(size: 0.9em)
  #align(center, barplot(bench.heap-16M.astack, (("baseline",), ("llvm", "llvm+static", "llvm+alias", "llvm+lazy", "llvm+pass",), ("wasm", "wasm+static", "wasm+alias", "wasm+lazy", "wasm+pass",)), width: 10cm, height: 8cm, label-angle: -70deg, cycle: (red, green, blue)))
]

== More Benchmarks: List
#slide[
  #set text(size: 0.9em)
  #align(center, barplot(bench.heap-64k.list, (("baseline",), ("llvm", "llvm+static", "llvm+alias", "llvm+lazy", "llvm+pass",), ("wasm", "wasm+static", "wasm+alias", "wasm+lazy", "wasm+pass",)), width: 10cm, height: 8cm, label-angle: -70deg, cycle: (red, green, blue)))
][
  #set text(size: 0.9em)
  #align(center, barplot(bench.heap-16M.list, (("baseline",), ("llvm", "llvm+static", "llvm+alias", "llvm+lazy", "llvm+pass",), ("wasm", "wasm+static", "wasm+alias", "wasm+lazy", "wasm+pass",)), width: 10cm, height: 8cm, label-angle: -70deg, cycle: (red, green, blue)))
]

== Questions
=== Why not Wasm #gc?
- Not supported by #llvm (yet)
- Issues with Wasm's type safety when overwriting a thunk with its result
