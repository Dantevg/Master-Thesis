#import "template.typ": *
#import "header.typ": *

#show: thesis.with(
  title: [Efficient WebAssembly GC Integration for a Functional Graph IR Language],
  description: [Improving performance of the #clean-llvm code generator by reducing memory operations],
  author: (
    name: "Dante van Gemert",
    email: "dante.vangemert@ru.nl",
    s-number: "s1032684",
  ),
  date: datetime.today(),
  supervisors: (
    company: [dr. Steffen Michels (TOP Software)],
    first: [dr. Mart Lubbers],
    second: [prof. dr. Sven-Bodo Scholz],
  ),
)

#abstract[
  When using the functional programming language Clean on the web, the existing #abc interpreter for WebAssembly has poor performance for non-trivial programs. Instead, we work on #clean-llvm, a code generator for Clean aiming to be more maintainable than the current one by using the #llvm compiler toolkit to generate target-specific assembly code and executables. At the same time it aims to achieve faster execution for WebAssembly than the interpreter. We integrate a garbage collector into #clean-llvm, implementing solutions for WebAssembly's restrictive semantics. We then implement several improvements to the performance of this #gc integration. Our generated Wasm code ends up running multiple times faster than the interpreter, and the #llvm output for native x86-64 code comes very close to the original compiler's speed.
]

#smallpage[
  #heading(level: 1, numbering: none, outlined: false)[Thank You]
  
  As you know, such a big project as a Master's thesis is not possible without help. Luckily, I got a lot of help---otherwise you would not be reading this. These awesome people deserve a thank you for making this a success.

  Firstly, I want to thank my first supervisor, Mart Lubbers. For providing fortnightly feedback on my writing, having conversations about typography, and giving me confidence that everything is going to work out.

  I am grateful to Steffen Michels for helping me with the practical side of things, aiding me in understanding Clean and #clean-llvm, and also for his feedback. TOP Software has been a nice place to do both my research internship as well as this thesis, for which I also want to thank Rinus Plasmeijer.

  Thank you to Camil Staps for taking the time to answer my questions about the #clean-llvm project and the #abc interpreter, and to John van Groningen for his extensive explanations of the Clean compiler's internals.

  I also thank Sven-Bodo Scholz for being the second assessor of my thesis.

  During the months of working on my thesis, I have often sat next to Paul Tiemeijer, who kept me company and with whom I had good chats about programming language design. It was nice having someone to complain to about #llvm, too.

  Although they understand not much of what I do (rightfully so!), my parents have supported me in other ways. They deserve a big thanks, and a warm hug.

  Lastly, I want to thank you!#footnote[If you are already mentioned above, thank you twice, I guess.] For reading. Hopefully you find it interesting.

  #v(1em)
  #show quote: set text(fill: luma(30%), style: "italic", size: 0.9em)
  #quote(block: true, quotes: false, attribution: [Solanum, Outer Wilds#footnote[I include a quote from a character in the game Outer Wilds at the start of each chapter.]])[
    It’s tempting to linger in this moment, while every possibility still exists. \
    But unless they are collapsed by an observer, they will never be more than possibilities.
  ]
]

#contents

// Outer Wilds quotes from https://hushbugger.github.io/outerwilds/text/#



// ================================



#show: thesis-body

= Introduction <ch:introduction>

#chapter-quote(attribution: [Solanum, Outer Wilds])[I admire your curiosity, friend. Let’s find out together.]

The web is now more used than it has ever been. Many things that used to be installed as a program on a user's computer now run as a web app in the browser. From basic functionality like e-mail, calendar and instant messengers, to word processors, spreadsheets, code editors and even professional applications like #smallcaps[3d] modelling software. The web with #smallcaps[html], #smallcaps[css] and JavaScript has become such a popular platform that it has also been used outside the traditional environment: some installable programs are just websites shipped with a browser engine, #smallcaps[lg]'s WebOS smart #smallcaps[tv] apps use it, and even SpaceX's space capsule control interface is made using web technologies.#footnote[https://www.reddit.com/r/spacex/comments/gxb7j1/comment/ft62781 #accessed(2025, 11, 18)]

The introduction and development of WebAssembly (Wasm)~@webassembly has made it feasible to use languages other than JavaScript for web development, without explicit browser support for that language. Wasm is, as the name suggests, a kind of assembly language for the web: any language (both high level and low level) can use Wasm as a compilation target. Recently, Wasm received support for proper tail calls. These are essential for functional languages, which do not use loops but recursion for iterating.

One project in a functional language that can benefit from Wasm is of special significance for this thesis: iTasks~@itasks is a framework for interactive web applications. It is the go-to basis for graphical and interactive programs for Clean~@clean, a pure and lazy functional programming language. iTasks is based on the paradigm of Task-Oriented Programming (#smallcaps[top])~@top, revolving around the concept of _tasks_ as the primary abstraction. These tasks run server-side, but they also contain small pieces of Clean code running in the browser for creating the #smallcaps[html] elements of the #ui. When these tasks interact with each other, an event gets sent to the server, which calculates how the #ui should change in response. This back-and-forth incurs a hit in #ui responsiveness, even though it is not always necessary. Large parts of an iTask application could theoretically run on the client side, which would not only improve responsiveness, but also availability, especially in case of a bad internet connection~@itasks-in-browser.

The small pieces of Clean code from iTasks running in the browser currently run in an interpreter~@clean-interworking. However, doing anything computationally complex on the client side still requires writing JavaScript, since the interpreter then becomes prohibitively slow. To fix this, we work on #clean-llvm~@clean-llvm, an alternative code generator for Clean that uses the #llvm~@llvm compiler toolkit to generate both WebAssembly code as well as executables for traditional (native) targets.

However, since any (untrusted) webpage can run Wasm code, it needs to have a much more secure design than for example x86-64 assembly. The result of that is that Wasm is more restrictive, and it does not support certain constructions that are used by the original Clean compiler and many other language implementations. One of the things which is trickier in Wasm is integrating a garbage collector (#gc). For most languages,#footnote[Clean with its #abc machine works a bit differently, see @ch:clean-abc.] #gc\s look through the call stack to find all the pointers to the heap that are live; all other heap values are then discarded by the #gc. However, this walking through the call stack is not supported in WebAssembly. In this thesis, we explore and evaluate ways to efficiently integrate a garbage collector into #clean-llvm, with a focus on WebAssembly performance. While this case study works with Clean and its graph rewriting intermediate language, findings from this research may be applicable to other languages that use graph rewriting, or any other functional language.

The rest of this introductory chapter provides some preliminary knowledge in @ch:preliminaries. We introduce the #clean-llvm project in @ch:clean-llvm. In @ch:gc-integration, we look at some strategies for integrating a garbage collector into #llvm for Wasm, and we choose two for the rest of the thesis. After that, @ch:performance-improvements introduces a number of improvements to the performance of the chosen integration methods, along with a benchmark tool used for evaluating and comparing these improvements. @ch:related-work[Chapter] goes over previous publications that are related to this work, and we conclude the thesis and provide suggestions for future work in @ch:conclusions.

== Background <ch:preliminaries>
This section provides some knowledge required to understand the rest of this thesis. We explain Clean and its #abc bytecode (@ch:clean-abc), #llvm (@ch:llvm), WebAssembly (@ch:webassembly) and copying garbage collectors (@ch:copying-gc).

=== Clean and ABC <ch:clean-abc>
Clean#footnote[Available at https://clean.cs.ru.nl/Clean and https://clean-lang.org.]~@clean is a pure and lazy functional programming language developed at the Radboud University. The first version dates back to 1987, just a few years before the introduction of Haskell which bears many similarities.
@fig:nfib-clean[Listing] shows a Clean implementation of the `nfib` function, a simple test program that returns the number of calls that happened during its evaluation. We use it here as a running example to show the various languages involved in the process of generating Wasm from Clean.

Clean programs are executed using graph rewriting. It compiles to #abc bytecode~@abc, a stack-based intermediate language with special support for this graph rewriting. The #abc machine uses three stacks: *A* (argument), *B* (basic value) and *C* (control). The #b-stack contains booleans, characters and integers, among others; each of these values fit within one machine word. The control stack is for return addresses and such. In this thesis, we look at the #a-stack, which is where references to the heap reside. The heap is a region of memory where we can freely allocate and de-allocate values without being bound to the semantics of a stack.

During compilation, each Clean function gets turned into one or more #abc entrypoints (or zero, if the function is not used at all). Each kind of entrypoint has its own usage: the *strict* entrypoint contains the actual implementation, the *evaluate arguments* entrypoint is used for arguments that are possibly not yet evaluated, the *node* entrypoint is for evaluating thunks (sometimes referred to as closures), and the *lazy* entrypoint is used when currying. We only encounter _strict_ and _node_ entrypoints in this thesis.

#place(top + center, float: true, grid(columns: 2, gutter: 2em, align: top)[
  #figure(
    caption: [Clean code for `nfib`.],
    ```clean
    nfib :: Int -> Int
    nfib n
      | n < 2 = 1
              = nfib (n-1) + nfib (n-2) + 1
    ```
  ) <fig:nfib-clean>
][
  #figure(
    caption: [#abc code for the `nfib` function, generated from @fig:nfib-clean by the Clean compiler.],
    kind: raw,
    grid(columns: 2, gutter: 1em)[
    #show: zebraw.with(highlight-lines: (4,5,6, 8,9,10,11))
    #show raw: syntax-abc
    #show "s2": abc-label
    #show "else.1": abc-label
    ```abc
    .o 0 1 i
    .r 0 1 i
    s2
      pushI 2
      push_b 1
      ltI
      jmp_false else.1
      pop_b 1
      pushI 1
    .d 0 1 i
      rtn
    else.1
      pushI 2
      push_b 1
      subI
    .d 0 1 i
      jsr s2
    ```
    ][
    #show: zebraw.with(numbering-offset: 17)
    #show raw: syntax-abc
    ```abc
    .o 0 1 i
      pushI 1
      push_b 2
      subI
    .d 0 1 i
      jsr s2
    .o 0 1 i
      update_b 1 2
      updatepop_b 0 1
      addI
      pushI 1
      push_b 1
      update_b 1 2
      update_b 0 1
      pop_b 1
      addI
    .d 0 1 i
      rtn
    ```
    ]
  ) <fig:nfib-abc>
])

We return to the `nfib` example program. The generated #abc code in @fig:nfib-abc contains two labels: the strict function entrypoint #abc-label[`s2`] and the jump target #abc-label[`else.1`]. Lines starting with a dot (#abc-annotation[`.o`], #abc-annotation[`.r`] and #abc-annotation[`.d`]) are annotations. They indicate the number of values on the *A* and *B* stacks, as well as the types of the *B* values (#abc-type[`i`], an integer, in this case). The first part in the code (between #abc-label[`s2`] and #abc-label[`else.1`]) corresponds to the first line of the Clean function: lines 4 to 6 (highlighted blue) are the comparison #inline-code(raw-clean("n < 2")), and lines 8 to 11 (also highlighted) return the integer #raw-clean("1"). Everything after the #abc-label[`else.1`] label corresponds to the second line of the Clean function: notice the two #raw-clean("jsr") ("jump subroutine") instructions for the recursive calls.

Nodes on the heap can either be in head normal form (#hnf, i.e. the node itself is evaluated, although its child nodes might not be) or a thunk (lazy; not yet evaluated). The first word of a node in head normal form is always a pointer to a _descriptor_, which contains meta-information about the kind of heap node: integers start with a pointer to the `INT` descriptor, etc. After that comes the actual data.
For thunks, the first word does not point to a descriptor but to the node entrypoint to use for evaluating it. The next words contain the arguments of the thunk. Node entrypoints themselves also have metadata attached such as their arity, which is placed right before the entrypoint in memory. The #gc needs to know the arity to determine the size of the allocated thunk.

@fig:singleton-clean[Listing] contains another Clean example that creates a list containing the integer #abc-number[`1`], subsequently using pattern matching in #raw-clean("hd") to retrieve that item again. Lists in Clean are linked lists, consisting of a chain of _cons_ nodes terminated by a _nil_ node (_nil_ is the empty list). We can see this in the generated #abc code in @fig:singleton-abc: create a node with #abc-label[`_Nil`] descriptor and arity #abc-number[`0`] (line 4), create an integer node with value #abc-number[`1`] (line 5), and finally create a #abc-label[`_Cons`] node using the top #abc-number[`2`] values on the #a-stack (line 6). @fig:singleton-diagram[Figure] shows a visual representation of the #a-stack and heap for these three steps.

#place(auto, float: true, grid(columns: 2, gutter: 2em, align: top)[
  #figure(
    caption: [Clean code for `singleton`.],
    ```clean
    singleton :: Int
    singleton = hd [1]
    
    hd :: [Int] -> Int
    hd [a:_] = a
    hd []    = 0
    ```
  ) <fig:singleton-clean>
][
  #figure(
    caption: [#abc code for the `singleton` function (#abc-label[`s2`]), generated from @fig:singleton-clean by the Clean compiler. #abc-label[`s3`] is the #raw-clean("hd") function (omitted here).],
    kind: raw,
    [
      #show: zebraw.with(highlight-lines: (4,5,6))
      #show raw: syntax-abc
      #show "s2": abc-label
      ```abc
      .o 0 0
      .r 0 1 i
      s2
      	buildh _Nil 0
      	buildI 1
      	buildh _Cons 2
      .d 1 0
      	jmp s3
      ```
    ]
  ) <fig:singleton-abc>
])

#figure(
  caption: [Schematic view of the #a-stack and heap for the three steps of creating a singleton list #raw-clean("[1]").],
  placement: auto,
  include "diagrams/astack-singleton.typ"
) <fig:singleton-diagram>

=== LLVM <ch:llvm>
#llvm~@llvm is a compiler project featuring a custom intermediate representation (#ir), an optimiser and several back ends like x86-64, Arm or WebAssembly. Also part of the project is the Clang compiler for C and C++, which uses the #llvm #ir and optimiser. #llvm is meant as an easy compilation target for programming languages, functioning as an optimising code generator. It makes it easier for languages to support new targets such as WebAssembly, since most of the work needed to support such a target is done in the #llvm project.

The #llvm #ir language is based on static single assignment (#ssa). This means that #llvm #ir consists of a sequence of instructions, each (optionally) with a name to refer them by. Unlike in many programming languages, there are no variables that can be assigned to multiple times: a name is bound to one single instruction and cannot be reassigned. This #ssa form makes most analyses, optimisations and transformations easier. The #llvm back end translates these variables to registers#footnote[Or, to locations on the stack for languages without registers, like WebAssembly.] (or stack slots if there are not enough registers). #llvm #ir is more high-level than typical assembly languages: it not only has #ssa variables, but also functions and a type system with composite types like arrays and structs. The #ir not only exists in-memory, but can also be saved to a file in both binary (`.bc`) and textual (`.ll`) form.

There are a number of features of #llvm #ir that are relevant for this thesis. 

==== Metadata
In #llvm #ir, functions, other globals and instructions can all have metadata attached. This carries non-essential information like debug information (`!dbg`) and optimisation hints to the compiler such as which pointers can and cannot alias (`!noalias` and `!alias.scope`#footnote[https://llvm.org/docs/LangRef.html#noalias-and-alias-scope-metadata #accessed(2026, 1, 12)]).

==== Function attributes
Besides metadata, functions can also have attributes like `noinline`, `alwaysinline`, `noreturn` and `willreturn`.#footnote[https://llvm.org/docs/LangRef.html#function-attributes #accessed(2026, 1, 12)] Among these is the `gc` attribute,#footnote[https://llvm.org/docs/LangRef.html#gc #accessed(2026, 1, 12)] which specifies which #gc strategy to use for that function. This strategy can be provided by a plugin, but #llvm also provides some built-in ones like the _statepoint-example_ strategy we look at in @ch:statepoints.

==== Operand bundles
Call instructions can have something closely related to metadata called _operand bundles_.#footnote[https://llvm.org/docs/LangRef.html#operand-bundles #accessed(2026, 1, 12)] As opposed to regular metadata, which can be dropped at any point, operand bundles cannot be removed from the instruction. This makes them suitable for transformations that are required for outputting correct code. Operand bundles are for example used for #llvm's statepoints (see @ch:statepoints).

==== Intrinsics
#llvm includes a range of intrinsics,#footnote[https://llvm.org/docs/LangRef.html#intrinsic-functions #accessed(2026, 1, 12)] which are called like regular functions in the #ir. They differ from regular function calls in that they do not get compiled to a function call, but rather a series of machine instructions defined by the compiler. These include garbage collection intrinsics, #box[C/C++] library functions (`llvm.abs.*`, `llvm.memcpy`, etc.), special arithmetics (bit manipulation, saturating or with overflow, fixed point, etc.), vector and matrix operations, debugging, and constrained floating point arithmetic.

Optimisation in #llvm is based on passes that run after each other in a pipeline, each of them working with the output of the previous pass. Each optimisation level (`-O0`, `-O1`, `-O2`, `-O3`) defines a pre-set pipeline of passes to run, but one can also manually specify a custom pipeline. There are three kinds of passes: *analysis* passes analyse the code and provide information for later passes, *transformation* passes transform and optimise the code in some way, and *utility* passes do neither of these things and are not used in a regular pipeline (they are for instance used for development or debugging). Passes are written in C++, like the rest of #llvm. In addition to the C++ #api, there is an #api for C with most common functionality, however not all features are available there. The C #api is useful for interacting with #llvm from languages other than C++.

#figure(
  caption: [#llvm code for the `nfib` function, generated from @fig:nfib-abc by the #clean-llvm code generator and manually cleaned up.],
  placement: auto,
  ```llvm
  define private i64 @nfib(i64 %n) {
  entry:
    %n_lt_2 = icmp slt i64 %n, 2
    br i1 %n_lt_2, label %lt, label %else
  
  lt:
    ret i64 1
  
  else:
    %n_2 = sub i64 %n, 2
    %nfib_2 = call i64 @nfib(i64 %n_2)
    %n_1 = sub i64 %n, 1
    %nfib_1 = call i64 @nfib(i64 %n_1)
    %sum = add i64 %nfib_1, %nfib_2
    %result = add i64 %sum, 1
    ret i64 %result
  }
  ```
)<fig:nfib-llvm>

An example #llvm #ir function is seen in @fig:nfib-llvm. It is a slightly simplified form of the output of #clean-llvm. A more in-depth description of the exact #llvm code that #clean-llvm generates is found in @ch:clean-llvm. An #llvm function is composed of basic blocks; this one has three (named #abc-label[`entry`], #abc-label[`lt`] and #abc-label[`else`]). A function has at least one basic block, although it does not need to be explicitly named like here. Each basic block contains a number of instructions (usually assigned to #ssa variables), followed by a single terminator instruction (#raw-llvm("br") or #raw-llvm("ret") in this case).

=== WebAssembly <ch:webassembly>
WebAssembly~@webassembly is a stack-based intermediate language which aims to be safe, fast, portable and compact. For an assembly language, it is quite high-level: it has structured control flow, functions, exception handling and garbage collection. It describes both a binary format and a textual representation, and one can be converted to the other. The textual representation actually has two forms: a more traditional reverse Polish notation (#smallcaps[rpn]) form and a folded s-expression form; see @fig:wasm-sexpr-comparison for a comparison.

#figure(
  caption: [Comparison of Wasm in RPN form (left) and s-expression form (right). It is best to read the RPN form by simulating the stack in your head: push the local at index #raw-clean("0") onto the stack (line 2), push the number #raw-clean("2") (line 3), subtract them from one another (line 4), and call function #text(fill: theme.other)[`$.Lnfib`] with the result (line 5, leaving the return value on the stack). The s-expression form looks more like a conventional programming language and makes the control flow and data flow clear, but it is just syntax sugar for the RPN form.],
  grid(columns: 2, gutter: 2em)[
    ```wasm
    ;; RPN form
    local.get 0
    i64.const 2
    i64.sub
    call $.Lnfib
    ```
  ][
    ```wasm
    ;; S-expr form
    (call $.Lnfib
      (i64.sub
        (local.get 0)
        (i64.const 2)))
    ```
  ]
)<fig:wasm-sexpr-comparison>

We continue the running example of the `nfib` function in @fig:nfib-wasm. The function starts with a #text(fill: theme.keyword)[`block`] instruction, which is Wasm's way of structured control flow. The `br_if` function inside this #text(fill: theme.keyword)[`block`] will jump to the end of this #text(fill: theme.keyword)[`block`] if the condition is false, thereby skipping lines 10 and 11.

#figure(
  caption: [Wasm code for the `nfib` function, generated from @fig:nfib-llvm by #llvm.],
  ```wasm
  (func $.Lnfib (type 10) (param i64) (result i64)
    (block  ;; label = @1
      (br_if 0 (;@1;)
        (i32.eqz
          (i32.and
            (i64.lt_s
              (local.get 0)
              (i64.const 2))
            (i32.const 1))))
      (return
        (i64.const 1)))
    (return
      (i64.add
        (i64.add
          (call $.Lnfib
            (i64.sub
              (local.get 0)
              (i64.const 2)))
          (call $.Lnfib
            (i64.sub
              (local.get 0)
              (i64.const 1))))
        (i64.const 1))))
  ```
)<fig:nfib-wasm>

=== Copying Garbage Collectors <ch:copying-gc>
We need two things for managing the heap: an allocator and a garbage collector. The simplest way of allocating space on the heap is called a _bump allocator_, which requires very little bookkeeping. We keep track of the first available heap location and call this the _heap pointer;_ it initially points to the start of the heap. To allocate, we use this location and we increment the heap pointer by the size of the allocation. If the new heap pointer is pointing outside the available heap space, we invoke the garbage collector. This is different to how for example reference counting #gc works,#footnote[Reference counting does not support cyclic data structures without modification or manual care from the programmer. Clean does not have reference counting, and implementing it for Clean may be impractical given these and other limitations.] where the #gc is triggered when a heap reference is freed as opposed to when allocating. An advantage of such a simple bump allocator is that it is very quick, which is especially important in languages that allocate lots of small objects.

A copying #gc is a kind of #gc that allows for using such a bump allocator. One of its selling points is that it results in a very compact heap arrangement, but a big downside is that it requires twice the available heap size to work. It operates by dividing the heap up into two _semispaces_, of which only one is active at a time. When collecting garbage, all heap allocations that are reachable from the stack get moved to the other semispace and the heap pointer is updated accordingly. Dead heap allocations (i.e. no longer reachable from the stack) are ignored, in fact the #gc does not know about them. This kind of #gc is stop-the-world, meaning that with a naive implementation, no part of the program can run in parallel with the #gc since heap values are being moved from one semispace to the other. @fig:copying-gc[Figure] shows a graphical example of garbage collection using a copying #gc and subsequent allocation with a bump allocator.

Another allocation technique is the free list. It turns the unallocated parts of memory into a linked list: every free block of memory contains a pointer to the next free block. When allocating, this linked list is traversed until a spot is found that is large enough for the object, and the free list is updated accordingly. De-allocating memory using a free list is done by adding the memory section to the linked list. A free list also enables compacting garbage collectors, which move allocated regions together, filling the empty space between these regions that has appeared at de-allocation.

The original Clean compiler has two options for garbage collection: either using a copying collector, or a mark-scan collector. Both of these automatically switch to a compacting collector as well, when needed.

#figure(
  caption: [Schematic view of collecting and allocating. Semispaces are marked with 'ss 1' and 'ss 2', the heap pointer with an arrow. The heap consists of 8 available words in this example.
  + At the start, two objects are allocated, and we want to allocate another three words. There is not enough space available, so we run the #gc. We only copy the active heap value to the other semispace.
  + After collecting, there is enough space, so we allocate space for a new heap value.],
  include "diagrams/garbage-collector.typ"
) <fig:copying-gc>



// ================================



= Clean-LLVM <ch:clean-llvm>

#chapter-quote(attribution: [Solanum, Outer Wilds])[
  // Are you ready to learn what comes next?
  As a child, I considered such unknowns sinister. \
  Now, though, I understand they bear no ill will. \
  The universe is, and we are.
]

We want to run Clean code on the web, for instance for use in iTasks. The #abc interpreter is fine for small pieces of code, but it is not fast enough to run more significant programs. That is why #clean-llvm~@clean-llvm is being developed. It plays a key role in compiling Clean to Wasm for fast execution on the web, bridging the gap between Clean's intermediate representation and #llvm, which can be compiled to Wasm.

In this chapter, we first explain the pipeline from Clean source code to the generated executable or Wasm code in @ch:clean-llvm-pipeline. We then introduce the basics of how #llvm code is generated from #abc code in @ch:stack-simulation. After that, @ch:register-pinning goes into detail on efficiently keeping track of some required global state. The rest of this chapter goes on to explain the Wasm-specific approach to node entrypoints in @ch:node-entrypoint-indirection and descriptor contents in @ch:descriptor-contents. Finally, in @ch:missing-features we list some functionality that still needs to be implemented.

== Pipeline Overview <ch:clean-llvm-pipeline>
We go through the steps in the compilation pipeline, from the Clean source file to the output executable. In a nutshell, we take in Clean's #abc bytecode and output #llvm #ir. The Clang compiler, which is part of #llvm, then generates code for both WebAssembly and x86-64 targets. We use automatically generated Clean #smallcaps[ffi] (foreign function interface) bindings to the #llvm #api for C to generate the output #llvm code. See @fig:pipeline for a graphical overview. To clearly differentiate the different Clean implementations, we call the existing implementation _baseline_ Clean.

+ _Clean #sym.arrow #abc._ We start with two files: a `.icl` file containing the implementation and a `.dcl` file with the exported definitions. The first step is done by the Clean compiler, specifically `cocl`. It compiles the `.icl` and `.dcl` file to #abc bytecode and outputs that to a `.abc` file. We only support single-module compilation in #clean-llvm at this point, but in the future, this step runs for each of the imported files when we include other Clean modules.

+ _#abc #sym.arrow #llvm #ir._ This is the part where we deviate from the original Clean compiler's compilation path. Our code generator (called `abc2bc`) takes this #abc bytecode and generates #llvm #ir. Since we use the #llvm #api, we can output both in the binary format (`.bc`) and in the textual format (`.ll`), without additional effort.

+ _#llvm #ir #sym.arrow Executable / Wasm._ Lastly, we give this #llvm file together with the source code for the runtime system to `clang`, which runs the #llvm pipeline of optimisations and transformations. The output of this is either an executable file (a `.exe` on windows or an #smallcaps[elf] on Linux), or a `.wasm` file for use in the browser.

#figure(
  caption: [A graphical overview of the #clean-llvm compilation pipeline. The #abc interpreter and baseline Clean pipelines are shown in grey. For brevity, not all targets of `clang` and `cg` are shown. Prelinked bytecode is fed as input to the #abc interpreter, and Wasm, files are run in the V8 #jit engine through Node.js.]
)[
  #show raw: set text(size: 0.9em)
  #include "diagrams/compilation-overview.typ"
] <fig:pipeline>

== Stack Simulation <ch:stack-simulation>
From each entrypoint in the #abc input file, we generate an #llvm function. This means that the #c-stack is no longer needed as the control flow is handled by #llvm. Values on the *A* and *B* stacks are translated to #llvm #ssa values. This is done by simulating these stacks during code generation, using #llvm values instead of real values. #llvm values can be a simple constant or a complex #ssa instruction. This simulation of the stack is possible because every value's location on the stack within a function's stack frame is statically known at every point in time. To explain the simulated stack, take a look at the following example with #abc code resulting from the Clean function #inline-code(raw-clean("answer = 37 + 5")).

#let sim-stack(..values) = {
  for (i, val) in values.pos().enumerate() {
    // text(fill: gray, str(i) + ": ")
    inline-code(raw-llvm(val))
    if i != values.pos().len() - 1 { ", " }
  }
}

#table(
  columns: 3,
  // stroke: none,
  stroke: (x, y) => if y == 0 { (bottom: 0.5pt + black) } else { none },
  align: (left, left, left),
  inset: ((y: 5pt, left: 0pt, right: 5pt), 5pt, (y: 5pt, left: 5pt, right: 0pt)),
  table.header[#abc code][explanation][simulated #b-stack],
  raw-abc("  pushI 5"), [Create #llvm integer constant #raw-llvm("5") and push it to the simulated #b-stack.], sim-stack("i64 5"),
  raw-abc("  pushI 37"), [Create #llvm integer constant #raw-llvm("37") and push it to the simulated #b-stack.], sim-stack("i64 5", "i64 37"),
  raw-abc("  addI"), [Take the top two #llvm values from the #b-stack. Create an #llvm #raw-llvm("add") instruction with these two operands, and push this instruction to the #b-stack (remember that #llvm instructions are also #llvm values).], sim-stack("add i64 37, 5"),
  raw-abc(".d 0 1 i"), [Annotation indicating that the following return instruction returns #raw-clean("0") #a-stack values, and #raw-clean("1") integer (#raw-abc("i")) on the #b-stack.], [],
  raw-abc("  rtn"), [Take the top #llvm value from the #b-stack and create an #llvm return instruction with it: #inline-code(raw-llvm("ret i64 %_1")) (we refer to the #raw-llvm("add") instruction with #raw-llvm("%_1"), its #ssa variable name in this example).], [(empty)],
)

The resulting #llvm code would look like the following, if we ignore that #llvm automatically collapses the #raw-llvm("add") instruction to a constant.
```llvm
define i64 @answer() {
  %_1 = add i64 37, 5
  ret i64 %_1
}
```

== Register Pinning <ch:register-pinning>
For allocating objects on the heap, we need to know at all times where the next available heap position is and how much free space there is left on the heap. These values are essentially global state which we need to keep track of. For performance reasons, we do not want to put them in a global variable which is constantly read and updated, because that results in lots of memory accesses for allocation-heavy programs. These values should really be in registers at all times, i.e. they should each be _pinned_ to a register. #llvm does not provide a way to do this, but the solution used by the #llvm code generators for GHC~@haskell-llvm and Erlang~@erlang-llvm is to pass these values as the first arguments to a function, using a calling convention that puts those in registers. One calling convention that does this is _fastcc_. This way, the values will always be in registers (at least across function call borders; #llvm is free to do anything with their registers within a function). Note that this only has an effect for native code generation; Wasm is too high-level and does not allow specifying a custom calling convention, nor does it have a concept of registers.

#block(breakable: false)[
We manually removed these register-pinned values from the example in @fig:nfib-llvm for clarity since the `nfib` function does not use them (it does not allocate). In practice, we pin a couple values to registers and `nfib`'s function signature looks more like this:
```llvm
define private fastcc { ptr, i64, i64 } @nfib(ptr %hp, i64 %heap_free, i64 %n)
```]
#block(breakable: false)[
Function calls look like this (#raw-llvm("%nfib_2") is the actual return value):
```llvm
  %_15           = call fastcc { ptr, i64, i64 } @nfib(ptr %hp, i64 %heap_free, i64 %n_2)
  %hp_new        = extractvalue { ptr, i64, i64 } %_15, 0
  %heap_free_new = extractvalue { ptr, i64, i64 } %_15, 1
  %nfib_2        = extractvalue { ptr, i64, i64 } %_15, 2
```]
#block(breakable: false)[
And returns look like this (corresponds to #inline-code(raw-llvm("ret i64 1")) in @fig:nfib-llvm):
```llvm
  %_10 = insertvalue { ptr, i64, i64 } undef, ptr %hp, 0
  %_11 = insertvalue { ptr, i64, i64 } %_10, i64 %heap_free, 1
  %_12 = insertvalue { ptr, i64, i64 } %_11, i64 1, 3
  ret { ptr, i64, i64 } %_12
```]

In order to reduce stack usage for Wasm, #clean-llvm accepts the `-ug` command-line flag. This changes the approach to use globals for the heap pointer and free heap space, instead of registers (`ug` stands for "use globals"). While this does reduce stack usage, it also incurs a performance cost of loading from and storing to system memory when accessing these values. Therefore, we do not use this flag now.

== Node Entrypoints for Wasm <ch:node-entrypoint-indirection>
We briefly touched on node entrypoints in @ch:clean-abc. Every node entrypoint has its arity and other metadata placed right before it in memory, which the #gc uses to determine the size of the allocated thunk. #llvm supports this with prefix data, which allows us to place arbitrary data before functions. WebAssembly's memory model complicates this: function addresses are consecutive integers, as if they are elements in a list of functions. This makes prefix data impossible, so we need a different solution for Wasm.

There are multiple ways to solve this, but we choose to implement it using an extra indirection. Instead of placing the metadata before the entrypoint, we place it in a global struct before a pointer to the entrypoint. The advantage of this is that the #gc does not need to be adapted since it only looks at the metadata. At the point of evaluating a node entrypoint, the code generator inserts an extra load instruction to walk through the added indirection.

We selectively enable this extra indirection for node entrypoints only when generating code for Wasm, so there is no performance impact for native targets.

== Descriptor Contents <ch:descriptor-contents>
As explained in @ch:clean-abc, nodes on the heap start with a pointer to a descriptor, which contains information about the type of node~@clean-lang-docs. Descriptors for records contain the number of basic values and heap references, the types of those basic values, and the name of the record. #adt descriptors also contain the number of arguments and the name of the #adt constructor, in addition to a flag indicating if it is actually a record with lazy arguments, as well as a curry table. This curry table is used when not all arguments are supplied to an #adt or function. Because currying is not implemented in #clean-llvm, we do not go into detail on the exact contents of this curry table.

For optimisation reasons, Clean's run-time system expects that the descriptors are laid-out in memory in a specific order. This is again a place where Wasm is restrictive: it does not provide us a way to specify the order of static data. We get around this by generating all descriptors in a single array. We then create #llvm aliases#footnote[https://llvm.org/docs/LangRef.html#aliases #accessed(2026,1,20)] for pointing to each descriptor.

Additionally, descriptors for #adt;s include a static #hnf node of arity 0 of that #adt, which is used by the garbage collector. This static node is located right before the descriptor itself in the descriptor array.

== Missing Functionality <ch:missing-features>
Being work-in-progress, #clean-llvm lacks some functionality that is required for generating code for more complex programs. Some of them are listed here.

To start, not all #abc instructions are implemented. In fact, a large amount is not yet implemented, or only partially. For this thesis and in the preceding internship, we implement some of these missing instructions in order to be able to run the programs we want to. We also modify the programs so that they no longer compile to unimplemented #abc instructions.

Currently we compile a single Clean file with no import statements. Not even the standard library is included, so every file needs to contain its own implementation of for instance the `+` operator on integers.

Finally, a hurdle for test programs is that they use #smallcaps[i/o], which is not implemented at this point. The only possibility for outputting text is that the integer returned from the main function is automatically displayed.



// ================================



= Basic GC Integration <ch:gc-integration>

#chapter-quote(attribution: [Prisoner, Outer Wilds])[
  Every decision is made in darkness. \
  Only by making a choice can we learn whether it was right or not.
]

We have now explained what #clean-llvm is and why it is useful. Since Clean is a garbage-collected language, we need to implement a #gc for #clean-llvm. It is not possible to use the one from the existing Clean compiler because that one uses hand-written assembly (and we cannot compile that to Wasm). We choose to integrate the copying #gc from the #abc interpreter, since it is already known to work for Clean, and because it is implemented in C (which Clang _can_ compile to Wasm).

This collector is a moving #gc, so the heap address of an object changes after each collection cycle. Therefore, the #gc not only needs to _read_ pointers in registers, but also _update_ them again after a #gc invocation, to reflect their new location. This needs to work without being able to inspect the run-time stack (which is not possible in Wasm) and without extra indirection (which would incur a performance penalty).

WebAssembly has its own solution for garbage collection, standardised in Wasm version 3.0.#footnote[https://webassembly.org/news/2025-09-17-wasm-3.0 #accessed(2025, 11, 18)] It has instructions to create heap values, and all garbage is automatically taken care of by the Wasm runtime. This has numerous advantages compared to shipping a #gc in Wasm code, and several language toolchains have (experimental) support for it~@wasmgc-blog. However, the WebAssembly back-end of #llvm is not yet updated to support the Wasm #gc instructions,#footnote[https://discourse.llvm.org/t/wasmgc-implementation-status/74821/2 #accessed(2025, 11, 18)] so we cannot use it. There are also difficulties stemming from Wasm's type safety, for instance when a thunk is evaluated to a head-normal form.#footnote[https://gitlab.com/clean-and-itasks/clean-llvm/-/issues/5#note_2254379710]

There are a number of ways in which we can integrate our own #gc into the #clean-llvm code generator. #llvm has built-in functionality for helping with this: the older _gcroot_ mechanism and the newer _statepoints_. gcroot is described as 'mostly of historical interest at this point'; it is no longer actively maintained, and is not bug-free.#footnote[See for example https://github.com/llvm/llvm-project/issues/31684 #accessed(2025, 11, 18), which we also encountered in preliminary testing.] Statepoints are intended to replace gcroot entirely, however the built-in #gc strategies for statepoints do not support WebAssembly, since they are based on generating stack maps which WebAssembly does not support. Lastly, we can of course implement a custom #llvm pass that does something like what these #llvm features do, which requires no platform support and should therefore be portable.

This chapter goes into detail on three main ways to integrate a copying #gc: by implementing a shadow stack manually (@ch:shadow-stack), by using #llvm's gcroot function (@ch:gcroot), or by using #llvm statepoints (@ch:statepoints).

== Custom Shadow Stack <ch:shadow-stack>
A way to let the garbage collector read and update heap pointers on the system stack, is to use a separate stack placed on the heap. We push _(spill)_ each live heap pointer to this stack before a #gc cycle and we pop _(restore)_ the newly relocated pointer again afterwards. This construction is called a shadow stack. Where this stack is located, how it is structured, when to spill and when to restore are all implementation decisions.

We generate code for such a shadow stack directly, at the same time as the other code generation. It is also possible to do this later on, which provides some advantages but also introduces its own challenges. We elaborate on that in @ch:statepoints. The advantage of doing this early on, during code generation, is that we still have all the information from the source #abc code, as well as the entire simulated #a-stack. There are never unused values on the #a-stack\; the Clean compiler ensures this. This means that every value on the #a-stack is live.

Before each function call, we spill the entire #a-stack of the current function. We exclude any values that are passed as arguments to this call, since they will appear in the callee's #a-stack. Functions are thus responsible for spilling their received arguments themselves. Immediately after the call, we restore these values again. After restoring, we never use the old values again, since they no longer point to the same object if garbage collection has occurred during the call.

== GCRoot <ch:gcroot>
The older mechanism for describing heap references makes use of three #llvm intrinsics: `llvm.gcroot`, `llvm.gcread` and `llvm.gcwrite`. The latter two are read and write barriers which are not useful for a copying garbage collector. gcroot requires each heap reference to be stored in an allocation on the system stack. This is done with the `alloca` function / instruction, which works like `malloc` but for the stack instead of the heap. A reference to this stack-allocated spot is passed to the `llvm.gcroot` intrinsic call, which needs to happen in the first basic block of a function.

The #llvm shadow stack #gc strategy makes use of the gcroot intrinsics to generate a shadow stack, implemented as a linked list of stack roots. It does not require any special treatment from the compilation target, so it is available anywhere. However, there are performance issues with `llvm.gcroot`:

- If garbage collection can happen before an #a-stack value is live (before it is created), its stack slot must be marked with a sentinel value (such as `null`) to prevent the #gc from reading uninitialised data. When a value reaches the end of its lifetime, its stack slot should also be marked with a sentinel value again. This was also noted by the Erlang #llvm back end~@erlang-llvm. // Additionally, there are still superfluous spills to the system stack, depending on the location of the spills to the `alloca`.

- Another trade-off with using `alloca` is that function arguments get an extra indirection: not the heap pointer itself, but the address of the `alloca` (which contains the heap pointer) is passed as argument. This forces the caller to spill every #a-stack value passed to a function call to system memory, even when that would otherwise not be necessary.

- Additionally, the code generator should take care to only allocate stack slots for #a-stack values that are actually live across function calls; #llvm does not rewrite `alloca` + `gcroot` instructions back to register instructions, since the `alloca` is used in the call to the `gcroot` intrinsic.

// https://eschew.wordpress.com/2013/10/28/on-llvms-gc-infrastructure/
// https://discourse.llvm.org/t/llvm-gcroot-suggestion/18585

#pagebreak() // TODO: remove
== Statepoints <ch:statepoints>
Garbage collection statepoints, usually called safepoints outside of #llvm, are a way to mark locations in the code where heap addresses can change due to the garbage collector. To mark a function call as statepoint, we replace it with a call to the `gc.statepoint` intrinsic, passing the original function and its arguments. We also note down which heap references are live across this call. The resulting statepoint is then used for retrieving the return value of the function, and for getting the new memory location of the live heap references. The specific implementation of the statepoint intrinsic ensures that the #gc knows what values are live, and that the code calling the statepoint knows the new location of these moved heap values.

#llvm includes two #gc strategies that use statepoints: _statepoint-example_ and _coreclr_. These both make use of stack maps and stack walking over the native system stack, which are in theory more performant than a shadow stack for targets that support it. In order to support Wasm when using statepoints, we write a series of passes to transform code with statepoints to use a custom shadow stack as in @ch:shadow-stack.

The advantage of generating code for a shadow stack in an #llvm pass is that we are able to run other optimisations before it, such as inlining and dead code elimination (see @ch:spilling-after-optimisation). This results in less call sites in general, and potentially less live values at those call sites. If a later #llvm pass removes a use of an otherwise live heap reference (thereby making it no longer live) after a function call, or if it removes said function call entirely, earlier generated spills remain even though they are no longer required. That is why it is important to run these optimisations _before_ generating spills.

We perform the following steps for generating statepoints:

+ All #a-stack values are marked with type #raw-llvm("ptr addrspace(1)"), a pointer in address space 1. Address spaces are used by some #llvm targets to separate pointers to different (physical) memory regions from one another, but here we only use them to determine which pointers are heap references. <item:add-addrspaces>

+ Functions that we generate are marked with #raw-llvm("gc \"statepoint-example\""). This signals to further passes that we want to transform code in these functions to use statepoints.

+ With this meta-information, we add calls to #llvm's statepoint intrinsics. The function call itself is replaced by `gc.statepoint`, which marks the actual statepoint. This intrinsic receives the callee and the call arguments. A list of live heap references is attached to this call with a #raw-llvm("\"gc-live\"") operand bundle. Uses of the return value of the original call get replaced by calls to the `gc.result` intrinsic, and further uses of live references are replaced by the `gc.relocate` intrinsic. <item:statepoints>

+ As mentioned in @item:add-addrspaces, address spaces have a meaning for the target platform. We need to transform code back to the default address space to avoid it being interpreted by the back-ends. For this, we use one of Julia's #llvm passes (`remove-addrspaces`#footnote[https://github.com/JuliaLang/julia/blob/54fde7e012e6883a5bc9acd964593c8b9c9b5c74/src/llvm-remove-addrspaces.cpp #accessed(2026,1,21)]) which also works in our case. <item:remove-addrspaces>

This is enough for x86-64 and #arm targets, since they can use the built-in _statepoint-example_ #gc strategy which uses stack-walking.#footnote[The implementation of this is left as future work. Instead, the solution for Wasm is used for all targets.] For WebAssembly, we take this as a starting point to further transform the code:

#[
#set enum(start: 5)
+ Since we need to know the current #a-stack pointer (`asp`) for spilling to it, we add it as a register-pinned variable (see @ch:register-pinning), adding a function parameter and return value to each function. <item:add-asp>

+ We then transform all statepoint intrinsics back to regular calls with spills and restores.
  - `gc.statepoint` is replaced with a regular function call. Before it, we spill each value that is present in the #raw-llvm("\"gc-live\"") operand bundle.
  - Uses of `gc.result` are restored to uses of the return value of the function call.
  - Each `gc.relocate` is turned into a restore, i.e. a load from the spilled #a-stack at the known index. <item:spill-asp>
]

=== LLVM Pass Pipeline
We use the following pipeline of #llvm passes. Those marked bold are custom passes: `remove-addrspaces` comes from Julia, while `place-asp-safepoints` and `add-asp` are contributions of this thesis.

#{
  show "place-asp-safepoints": set text(weight: "bold")
  show "remove-addrspaces": set text(weight: "bold")
  show "add-asp": set text(weight: "bold")
  ```
  globaldce,cgscc(inline,adce),function(place-asp-safepoints),remove-addrspaces,add-asp,globaldce,adce,gvn
  ```
}

An explanation of these passes:
#{
table(
  columns: 2,
  stroke: none,
  inset: ((y: 5pt, left: 0pt, right: 5pt), (y: 5pt, left: 5pt, right: 0pt)),
  text(size: 0.9em, baseline: 0.1em)[`globaldce`], [Global Dead Code Elimination. Removes unused (dead) functions and global variables.],
  text(size: 0.9em, baseline: 0.1em)[`inline`], [Replaces function calls with the callee's body. This not only eliminates function call overhead, but more importantly it allows further optimisations to be more effective since the function body is put in context of its call. Not all function calls are inlined; whether to inline or not is decided based on a heuristic. For example, large functions (with a lot of instructions) tend not to be inlined.],
  text(size: 0.9em, baseline: 0.1em)[`adce`], [Aggressive Dead Code Elimination. Removes all instructions whose output is not used.],
  text(size: 0.9em, baseline: 0.1em)[`gvn`], [Global Value Numbering. Further eliminates redundant instructions and memory loads.],
  text(size: 0.9em, baseline: 0.1em)[`place-asp-safepoints`], [Replace function calls with calls to #llvm's statepoint intrinsic functions. Corresponds to @item:statepoints[step] above. We do this for every call that is not in tail call position: there can never be active heap references after a tail call. At each call site, we collect a list of live heap references. We do this by looking at each operand of each instruction that comes after the call, adding it to the list if it is defined before the call instruction. Then, for each live heap reference, every use that comes after the call is replaced by the inserted `gc.relocate` call.],
  text(size: 0.9em, baseline: 0.1em)[`remove-addrspaces`], [Transform code using address space 1 back to the default. Corresponds to @item:remove-addrspaces[step] above.],
  text(size: 0.9em, baseline: 0.1em)[`add-asp`], [Replace statepoint calls with normal function calls and add spills and restores. Corresponds to @item:add-asp[step] and @item:spill-asp[] above. Since #llvm does not allow for changing the signature of existing functions, we create new ones with an added #a-stack pointer parameter, and copy over the function body. We then transform each statepoint back into a regular call, making sure to call the new function which has the #a-stack pointer parameter when applicable.],
)
}

== Wrap-Up
This chapter introduced three ways of connecting a garbage collector with a shadow stack: either by manually generating spill and reload instructions, by using #llvm's gcroot feature or using statepoints. We implement both the custom shadow stack as well as the set of #llvm passes using statepoints. In the rest of this thesis, we improve these implementations further and we compare their performance.



// ================================



= Performance Improvements <ch:performance-improvements>

#chapter-quote(attribution: [Pye, Outer Wilds])[Mission: Science compels us to explode the sun!]

The last chapter introduced the basic way of integrating the #gc, which comes down to two different mechanisms for spilling the #a-stack. These implementations are far from optimal, and there are a number of improvements to the performance possible. In this chapter, we introduce the underlying issues, we explain what causes them, and we show how to fix them to generate more performant code. Specifically, we add two general optimisations that apply to both of these mechanisms: static nodes (@ch:static-nodes) and #llvm's alias metadata (@ch:alias-metadata). For the custom shadow stack, we restore lazily in @ch:lazy-restore, and we run #llvm optimisation passes before generating statepoint-based spills in @ch:spilling-after-optimisation. We also evaluate the speedup gained by implementing each solution. At the end of this chapter, in @ch:benchmark-results, we quantitatively compare these different improvements to both the original Clean compiler and to the #abc interpreter. Firstly though, we explain our benchmark methodology.

#let commit(sha) = link("https://gitlab.com/clean-and-itasks/clean-llvm/-/commit/" + sha, raw(sha.slice(0, 7)))

// We compare:
// - orig spilling: #commit("7bb328c5ff4c20755e148078c7e2cf896e3a6911") + cherry-picked f9b24268
// - orig spilling + *static nodes*: #commit("9bab0ae9fed6553e257bc51f6e5c51dd3c366355") + cherry-picked f9b24268
// - orig spilling + static nodes + *alias*: #commit("099d07fe98dcd006a2256d4f7f162964c6274ef2") + cherry-picked f9b24268
// - (orig spilling + static nodes + *hoist / sink*)
// - orig spilling + static nodes + *lazy restore*: #commit("65d0eb18277a23960f7e9931b47a4ad1fa66ef2d") + cherry-picked f9b24268
// - llvm pass spilling + static nodes + alias: #commit("bed37332cfd6d3d33cb1aa24f57a4534082313b2")

== Benchmarking
In this section, we introduce the benchmark tool we use to measure the runtime (@ch:benchmark-script), we show the actual programs that we benchmark (@ch:benchmark-programs), and we go over the impact of heap size on performance (@ch:benchmark-consistency). We are only interested in runtime performance---code size, memory usage and compilation time are of lesser importance for this thesis. All benchmarks are run on an #smallcaps[amd] Ryzen 7 2700x with 16#smallcaps[gb] of memory,#footnote[The benchmark programs do not get to use all of this memory. We run them with both 64kiB and 16MiB of memory as we explain in @ch:benchmark-consistency.] running Pop!\_OS 22.04 and using Clang 20.1.8 and Node.js 24.1.0.

=== Benchmark Tool <ch:benchmark-script>
We use a shell script called `benchmark.sh` to compare runtime performance between different targets, code versions and compilation flags. It takes care of compiling, running, capturing run-times and displaying a statistical comparison of the results. The output formatting and statistical computation is inspired by Hyperfine~@hyperfine, an open-source tool for benchmarking executables. Instead of using Hyperfine, we develop custom tooling for running benchmarks that directly integrates with the generated executable in order to remove as much variability from process creation and start-up time as possible.

With generated #llvm as well as for the #abc interpreter, we use a loop in C and JavaScript, respectively, that repeatedly calls the entry-point function. For baseline#footnote[Remember that _baseline_ Clean refers to the existing implementation, as opposed to #clean-llvm.] Clean, this is done with a Clean program instead. This difference is unavoidable and should not result in any meaningful change in measured run-times.

The time each benchmark run takes is measured by calling the `clock_gettime` syscall with the `CLOCK_MONOTONIC` time. We do not use `CLOCK_REALTIME` since that clock experiences forwards and backwards jumps in time to align with wall-clock time. `CLOCK_MONOTONIC` does not jump, but its frequency is still adjusted to match network time. This makes `CLOCK_MONOTONIC_RAW` an even better fit for benchmarking since its frequency is not adjusted. However, the JavaScript standard library (which we use when benchmarking Wasm) only provides the `performance.now()` function, which uses `CLOCK_MONOTONIC` internally (in Node.js). It is more important to use the same clock everywhere than to use the most accurate one: `CLOCK_MONOTONIC_RAW` may have a slightly different frequency than `CLOCK_MONOTONIC`, so using both would skew benchmark results.
At the end of each run, the measured time is written to the standard error output stream, to be read by the benchmark script.

Just-In-Time (#jit) interpreters, like the ones used for running Wasm code, most often experience a warm-up phase where it takes some time before run-times settle to a stable value~@benchmark-warmup. To avoid that influencing the results, the benchmark tool first discards $m$ warm-up runs after which $n$ benchmark runs follow, where $n$ and $m$ are configurable and need to be set manually to suit the runtime of a single run. These warm-up runs are discarded for every executable: for the generated #llvm as well as for baseline Clean and the #abc interpreter.

Additionally, we run the `node` command with the `--no-liftoff` flag, which disables V8's Liftoff #jit compiler. This single-pass compiler is designed to reduce startup times, and the code it generates is used until the optimising TurboFan compiler is done compiling~@v8-liftoff. We want to benchmark the stable case (the TurboFan output), so we disable the Liftoff compiler. Interestingly, this flag sometimes makes the generated code _slower_, not faster. Regardless, we keep it enabled for our benchmarks.

The benchmark script has functionality to automatically replace functions in generated #llvm #ir files. This patched function is for example hand-optimised to test different strategies. We also use this for testing with the #gc disabled in @ch:benchmark-consistency, by replacing the looping function with one that resets the heap pointer each loop. 

We use two operating system features to improve inter-run variability. Firstly, we pin the program to a single #cpu core with the `taskset` command to prevent it from being moved to a different core while it is running. Secondly, we disable #cpu frequency scaling and run the core at a fixed clock speed. Since frequency scaling is #smallcaps[os] and processor specific, it is not included in the benchmark script and needs to be set manually.

=== Benchmark Programs <ch:benchmark-programs>
In order to compare the speedup gained from the different implementations in the coming sections, we must use the same benchmark programs. Since #clean-llvm does not yet support all #abc instructions, there is only a limited set of benchmarks we can support. Therefore, we only benchmark three programs. We choose one benchmark called _binarytrees_#footnote[https://benchmarksgame-team.pages.debian.net/benchmarksgame/description/binarytrees.html#binarytrees #accessed(2025, 11, 27)] from the Computer Language Benchmarks Game~@clbg, an online repository of benchmark programs and results for a number of different language implementations. In the past, Clean was part of this list of languages, but it is not anymore at this time. Another benchmark we use is _list_ from the #abc interpreter tests, and finally we use one program _(astack)_ written with the purpose to show the effects of the optimisations we implement.

==== Binarytrees
This is an adaptation of Hans Boehm's GCBench#footnote[https://hboehm.info/gc/gc_bench/ #accessed(2025, 12, 2)]---a program to test #gc performance. We use it because it is easily modified to not use any #smallcaps[io] (which is not yet implemented in #clean-llvm), yet it is not as small as other benchmarks and it still uses the heap. It first allocates one large binary tree that is live until the end of the program, and then creates many shorter-lived trees of varying depth in a loop.

A Clean implementation of this program is available via the internet archive.#footnote[https://web.archive.org/web/20111118030741/http://shootout.alioth.debian.org/u64/program.php?test=binarytrees&lang=clean&id=3 #accessed(2025,11,27)] We use that implementation with a few modifications: we remove #smallcaps[io] operations and instead add up all intermediate results, and we remove the integer from the tree node to avoid generating ABC instructions that are not yet implemented in #clean-llvm. In addition, we manually add the definitions for the used operators, since the standard library cannot be imported yet. The resulting source code is found in @ch:appendix:binarytrees.

// https://web.archive.org/web/20121201015104/http://shootout.alioth.debian.org/
// https://web.archive.org/web/20010124090400/http://www.bagley.org/~doug/shootout/
// https://benchmarksgame-team.pages.debian.net/benchmarksgame/

==== List
A very simple program that creates a long list of increasing integers and then sums it. See the code in @ch:appendix:list. Since this program does not do much with the #a-stack (which contains only the list), the optimisations in this chapter do not have much effect.

==== Astack
This program consists of a loop, repeatedly calling a function that creates 16 heap values. The function first creates a list of all of them and passes that to a dummy function (`isNotEmpty`, which simply returns #raw-clean("1") if the list contains at least one item, #raw-clean("0") otherwise). It then passes a list of just one heap value to the dummy function, followed by a list of another heap value, and lastly it passes a list of all the heap values again. The code is attached in @ch:appendix:astack. Repeatedly using many values across function calls is meant as a stress-test for spilling and restoring.

=== Collection, Caching and Consistency <ch:benchmark-consistency>
#let bench-astack_mult-consistency = load-benchmark("benchmark/astack_mult-consistency.csv")
#let bench-astack_mult-meta = (
  "nogc": (name: [no #gc], cycles: 0, time: 0.000000, cache-references: 7017358, cache-misses: 1175706, faults: 138, branches: 1064064885),
  "1kiB": (name: [1~kiB], cycles: 200000000, time: 19571.784650, cache-references: 46662475, cache-misses: 6933143, faults: 136, branches: 89936194810),
  "2kiB": (name: [2~kiB], cycles: 100000000, time: 2099.169011, cache-references: 15845088, cache-misses: 3202251, faults: 138, branches: 7002080488),
  "4kiB": (name: [4~kiB], cycles: 33333333, time: 704.331578, cache-references: 13744853, cache-misses: 2823634, faults: 139, branches: 3044261893),
  "8kiB": (name: [8~kiB], cycles: 16666666, time: 352.578321, cache-references: 45842385, cache-misses: 2342326, faults: 140, branches: 2054384682),
  "16kiB": (name: [16~kiB], cycles: 8333333, time: 176.372516, cache-references: 418637140, cache-misses: 1455872, faults: 146, branches: 1558916119),
  "32kiB": (name: [32~kiB], cycles: 4109589, time: 502.186692, cache-references: 3266315728, cache-misses: 2203992, faults: 153, branches: 3414043762),
  "64kiB": (name: [64~kiB], cycles: 2040816, time: 44.708111, cache-references: 3173624833, cache-misses: 1577964, faults: 168, branches: 1185029553),
  "128kiB": (name: [128~kiB], cycles: 1015228, time: 107.216283, cache-references: 3544810717, cache-misses: 70136177, faults: 201, branches: 1514330543),
  "256kiB": (name: [256~kiB], cycles: 507614, time: 11.200902, cache-references: 5271147720, cache-misses: 72992962, faults: 265, branches: 1094515584),
  "512kiB": (name: [512~kiB], cycles: 253486, time: 29.081870, cache-references: 6219141299, cache-misses: 81121722, faults: 393, branches: 1176911093),
  "1MiB": (name: [1~MiB], cycles: 126743, time: 2.893698, cache-references: 6213588810, cache-misses: 77835824, faults: 649, branches: 1072002796),
  "2MiB": (name: [2~MiB], cycles: 63331, time: 1.489911, cache-references: 6212657188, cache-misses: 78744374, faults: 1161, branches: 1080315876),
  "4MiB": (name: [4~MiB], cycles: 31666, time: 4.259110, cache-references: 6234843588, cache-misses: 105220642, faults: 2185, branches: 1111192040),
  "8MiB": (name: [8~MiB], cycles: 15832, time: 9.697853, cache-references: 6246934014, cache-misses: 100884210, faults: 4234, branches: 1119211114),
  "16MiB": (name: [16~MiB], cycles: 7916, time: 0.558204, cache-references: 6247212117, cache-misses: 100588005, faults: 8328, branches: 1118965269),
  "32MiB": (name: [32~MiB], cycles: 3958, time: 3.213222, cache-references: 6253547403, cache-misses: 103715153, faults: 16522, branches: 1132415892),
  "64MiB": (name: [64~MiB], cycles: 1979, time: 1.416612, cache-references: 6249282167, cache-misses: 98633266, faults: 32906, branches: 1139618195),
  "128MiB": (name: [128~MiB], cycles: 990, time: 0.241626, cache-references: 6256475375, cache-misses: 98747124, faults: 65673, branches: 1169385536),
  "256MiB": (name: [256~MiB], cycles: 495, time: 0.123830, cache-references: 6271491207, cache-misses: 99928272, faults: 131208, branches: 1235151880),
  "512MiB": (name: [512~MiB], cycles: 248, time: 0.064514, cache-references: 6317239027, cache-misses: 105245080, faults: 262279, branches: 1373661100),
  "1GiB": (name: [1~GiB], cycles: 124, time: 0.031046, cache-references: 6374637250, cache-misses: 108185214, faults: 524425, branches: 1639522790),
)

#figure(
  caption: [The runtime (left axis) and number of cache misses (right axis) for each heap size, for the `astack` program. The sizes of the #l1 and #l2 caches are marked with dashed lines. Note the sudden increase in cache misses at 128 kiB and 4 MiB, and the sudden increase in runtime around 2 MiB and 4 MiB.],
  placement: auto,
  context lilaq.diagram(
    width: 21cm - 2 * 2.5cm, // fits to page margin exactly (if grid margin is equal on left and right)
    xaxis: (
      ticks: bench-astack_mult-meta.values().map(it => it.name)
        .map(align.with(right))
        .map(box.with(width: 37pt))
        .map(rotate.with(-45deg, reflow: true))
        .map(move.with(dx: -10pt))
        .enumerate(),
        subticks: none,
        mirror: false,
    ),
    ylabel: [#box(width: 5pt, height: 5pt, ..cell-colour(red, width: 0.5pt)) runtime (ms)],

    yaxis: (mirror: false),
    lilaq.yaxis(
      position: right,
      label: [#box(width: 5pt, height: 5pt, fill: hatched(..cell-colour(aqua, width: 0.5pt), flip: true), stroke: cell-colour(aqua, width: 0.5pt).stroke) cache misses],
      lilaq.bar(
        range(bench-astack_mult-consistency.len()),
        bench-astack_mult-meta.values().map(meta => meta.cache-misses / bench-astack_mult-consistency.values().first().len()),
        offset: 0.2,
        width: 0.4,
        fill: hatched(..cell-colour(aqua, width: 0.5pt)),
        stroke: cell-colour(aqua, width: 0.5pt).stroke,
      )
    ),
    
    lilaq.bar(
      range(bench-astack_mult-consistency.len()),
      bench-astack_mult-consistency.values().map(runs => mean(runs)),
      offset: -0.2,
      width: 0.4,
      ..cell-colour(red, width: 0.5pt),
    ),

    lilaq.plot(
      range(bench-astack_mult-consistency.len()).map(x => x - 0.2),
      bench-astack_mult-consistency.values().map(runs => mean(runs)),
      yerr: bench-astack_mult-consistency.values().map(runs => stddev(runs)),
      color: black,
      stroke: none,
    ),

    lilaq.vlines(
      9.5, 13.5,
      stroke: (paint: black, thickness: 0.5pt, dash: "dashed")
    ),
    lilaq.xaxis(
      position: top,
      ticks: ((9.5, l1), (13.5, l2)),
      subticks: none,
    )
  )
) <fig:benchmarks-heap-size>

Ideally, we want each run of the benchmark to take an identical amount of time. Sadly, the real world makes this impossible, but we can come close to it. We already explained how we get rid of startup time and process scheduling differences by measuring individual runs with `CLOCK_MONOTONIC` time. Another source of inter-run variability is the impact of heap size on caching.

To illustrate that, we look at `astack`, which has very little heap space in use at a time since it runs the same function in a long loop. We compare the runtime of this program in a range of heap sizes, from 1 kiB (the smallest possible for this program) to 1 GiB. Additionally, we compare to a version where we reset the heap pointer between each iteration of the loop (named _no #gc;_), so it uses the least amount of heap space possible. We not only measure the runtime of the program, but also the time spent collecting garbage and the number of #gc invocations. Lastly, we use the `perf` command#footnote[`perf stat -e faults,cache-misses`] to gather hardware statistics: the number of page faults and cache misses. The results of this are in @tbl:benchmarks-heap-size, and the resulting runtimes and cache misses are visualised in @fig:benchmarks-heap-size.

#figure(
  caption: [
    Numbers per run of the `astack` program, for each heap size:
    - the total runtime including #gc,
    - the time spent doing #gc and the number of cycles,
    - the amount of page faults and cache misses.
    Observe that greater heap sizes correspond to less #gc cycles and more page faults.
  ],
  placement: auto,
  table(
    columns: 8,
    align: bottom + right,
    stroke: (x, y) => if y == 0 { (bottom: 0.5pt + black) } else { none },
    inset: (4pt, (left: 4pt, right: 2pt, y: 4pt), (x: 2pt, y: 4pt), (left: 2pt, right: 4pt, y: 4pt), 4pt, 4pt, 4pt, 4pt),
    column-gutter: (5pt, 0pt, 0pt, 5pt, 0pt, 5pt, 0pt),
  
    table.header([heap size], [runtime], [#sym.plus.minus stddev], [(relative)], [#gc time], [#gc cycles], [page faults], [cache misses]),
    ..for (key, runs) in bench-astack_mult-consistency {
      let meta = bench-astack_mult-meta.at(key)
      let avg = mean(runs)
      (
        meta.name,
        [#num(avg, digits: 2, unit: "ms")],
        [#sym.plus.minus #num(stddev(runs), digits: 2, unit: "ms")],
        [(#num(avg / mean(bench-astack_mult-consistency.nogc), digits: 2)#sym.times)],
        if meta.cycles == 0 { smallcaps[n/a] } else { num(meta.time / runs.len(), digits: 2, unit: "ms") },
        num(meta.cycles / runs.len(), digits: 0),
        num(meta.faults / runs.len(), digits: 0),
        num(meta.cache-misses / runs.len(), digits: 0),
      )
    }
  )
) <tbl:benchmarks-heap-size>

The figure clearly shows that a heap of 2 MiB causes slower runtimes, and even more so for 4 MiB and above. This is very likely related to the #l2 cache size of the processor used, which is 4 MiB. If we account for the fact that the actual allocated memory is double the usable heap space because of the semispace allocator, the correspondence becomes clear between the #l2 cache size and the point where runs start taking longer. We also see a sudden increase in cache misses starting at 128 kiB. A heap of that size still perfectly fits in the 256 kiB of #l1 cache, but not together with the #a-stack and system stack.#footnote[We allocate 1 kiB for the #a-stack, which is enough for all benchmarks.] The takeaway of this is that it is beneficial to use a small heap size. Not too small, however, since the time spent in the garbage collector then starts becoming significant: take a look at the #gc time and number of cycles in the top few lines of @tbl:benchmarks-heap-size. A heap size of 64 kiB is close to ideal, both regarding the runtime as well as the standard deviation, which is important for benchmarking.

Sadly, not all programs fit completely in the #l2 cache. `binarytrees` is one of those, requiring at least 16 MiB of heap. Because we still want to compare the programs with a smaller heap size for less variability, we benchmark with two heap sizes: 64 kiB (excluding `binarytrees`) and 16 MiB.

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

#let benchmarks-summary-tables(base, new) = grid(columns: (1fr, 1fr),
  benchmarks-summary(bench.heap-64k, title: [*#new* / #base#h(1fr)64kiB], base, new),
  benchmarks-summary(bench.heap-16M, title: [*#new* / #base#h(1fr)16MiB], base, new),
)

#let summary-tables-caption(base, chapter, raw: false) = [Relative runtimes of the `list`, `astack` and `binarytrees` benchmarks. Each column is compared separately; the runtime on x86-64 with 64kiB of heap is relative to the x86-64 runtime #if raw { base } else [of _#base;_] (#ref(chapter)) with 64kiB of heap, and Wasm results are compared to Wasm results.]

== Static Nodes <ch:static-nodes>
Optimisation is often about _doing less_. That is why we first focus on reducing the number of garbage-collectable references to the heap. #adt constructors with no arguments (like nil; the empty list) are only ever one value. We store that value as a static node in the executable. This is something that is also done by baseline Clean. We also store some often-used nodes here: booleans, all characters and integers up to 32. This results in doing less in multiple ways:
+ Perhaps obviously, it reduces the time it takes to create such nodes---they do not actually need to be created, merely referenced.
+ By storing just one instance of these values, we free up space on the heap that these values would otherwise occupy. As an example, a (fully evaluated) list of small integers now only needs to store the cons nodes in the heap and not the integers themselves. As a result, the heap fills up less quickly, and the garbage collector needs to run less frequently.
+ Since the static nodes are not garbage collected, they do not need to be spilled. This reduces the time spent spilling and the time spent by the garbage collector walking through the shadow stack. The shadow stack is also smaller, which leaves more space in the processor cache.

An example of how the #llvm code as generated by @ch:shadow-stack changes as a result of using static nodes is seen in @fig:static-nodes. Since using static nodes is a basic improvement that does not interfere with other optimisations, it is used in all further optimisations in the remainder of this chapter: all further improved versions also use static nodes where possible.

#figure(
  caption: [
    Comparison of storing the integer #raw-clean("1") on the heap at address #raw-llvm("%_1"), without (left) and with (right) static nodes.
    - Without static nodes, we first store the integer descriptor on the heap (line 1), followed by the integer #raw-clean("1") (line 3). The heap address of the descriptor is put on the heap at the given address (line 4).
    - With static nodes, we directly store the address of the static integer #raw-clean("1") node on the heap.
  ],
  grid(columns: 2, gutter: 2em,
    ```llvm
      store ptr getelementptr (i8, ptr @INT, i64 2), ptr %_2
      %_3 = getelementptr i64, ptr %_2, i64 1
      store i64 1, ptr %_3
      store ptr %_2, ptr %_1, align 8
    ```,
    ```llvm
      store ptr getelementptr (i64, ptr @small_integers, i64 2), ptr %_1
    ```,
  )
) <fig:static-nodes>

=== Benchmark Results
Using static nodes has a positive effect across the board. It is of course more apparent for programs that use a lot of zero-argument #adt constructors or small integers. `list` and `astack` do not use many of those, while `binarytrees` of course creates relatively many leaf nodes (which are #adt;s with no arguments). We see the effect of this in @tbl:static-nodes, where `binarytrees` is #improvement(bench.heap-16M.binarytrees, "llvm", "llvm+static") faster for x86-64 and #improvement(bench.heap-16M.binarytrees, "wasm", "wasm+static") faster for Wasm.

#figure(
  caption: summary-tables-caption("before optimisations", <ch:shadow-stack>, raw: true),
  benchmarks-summary-tables("base", "static")
) <tbl:static-nodes>

#pagebreak() // TODO: remove
== Alias Metadata <ch:alias-metadata>
#llvm sometimes does not optimise away some redundant `load`/`store` instructions because it does not have enough information to be certain that they really are redundant. A simple case is where a memory address gets written to twice, but in between there is another write to a different memory address. In principle, #llvm should be able to remove the first `store` instruction. It does not, however, since the two memory references may actually point to the same address (i.e. they may alias). We inform #llvm that these memory references do not alias by attaching `!alias.scope` and `!noalias` metadata to all memory access instructions. With these annotations in place, #llvm removes some redundant loads and stores, which primarily occur across inlined calls.

Specifically, we define three alias scopes: one for references to the heap, one for references to the #a-stack and one for references to globals. We annotate each `store` instruction with its corresponding #box[`!alias.scope`], and add the other alias scopes to #box[`!noalias`]. The same happens with `load` instructions. This way, #llvm knows that reads and writes to the heap never alias those to the #a-stack.

Adding alias annotations is again a basic improvement that does not interfere with other optimisations, so it is used in all further optimisations in the remainder of this chapter: all further improved versions also have alias annotations (in addition to using static nodes).

#figure(
  caption: [Example of how the alias metadata gets attached to a load from the heap and a store to the heap. These instructions operate in the #raw-llvm("\"heap\"") scope (`!1`) and do not alias the #raw-llvm("\"globals\"") and #raw-llvm("\"a_stack\"") scopes (`!7`).],
  ```llvm
    %_5 = load ptr, ptr %_2, align 8, !alias.scope !1, !noalias !7
    ; ...
    store ptr %_41, ptr %_53, !alias.scope !1, !noalias !7

    !0 = !{!"alias"}       ; alias domain
    !1 = !{!2}             ; list of the heap scope
    !2 = !{!"heap", !0}    ; heap scope (in the alias domain)
    !3 = !{!4}             ; list of the globals scope
    !4 = !{!"globals", !0} ; globals scope (in the alias domain)
    !5 = !{!6}             ; list of the A-stack scope
    !6 = !{!"a_stack", !0} ; A-stack scope (in the alias domain)
    !7 = !{!4, !6}         ; list of all scopes except the heap scope
    !8 = !{!2, !6}         ; list of all scopes except the globals scope
    !9 = !{!2, !4}         ; list of all scopes except the A-stack scope
  ```,
)

=== Benchmark Results
For the `astack` benchmark, adding alias metadata to memory access instructions gives a slight performance improvement. This example program spills the same values across multiple consecutive function calls. #llvm is able to detect that some spills are redundant, since the values in question have already been spilled to the same locations earlier.

When looking at the Wasm results, there is no performance improvement for `list` and `astack`. This seems to indicate that V8's #jit compiler already removes (some of) the redundant stores and loads.

#figure(
  caption: summary-tables-caption("static", <ch:static-nodes>),
  benchmarks-summary-tables("static", "alias")
)

== Lazy Restoring <ch:lazy-restore>
Many Clean functions contain more than two function calls. In a situation where #a-stack values created at the start of such a function need to live through to the end of the function, these values will constantly be spilled and restored for each call in between, even when they are not used between the function calls. #llvm optimises away some of these redundant spills and restores, but not all of them.

For each value on the simulated #a-stack, we keep track of whether it has been spilled or not. The internal representation stores the value itself together with its spilled address. We distinguish two cases: *active* for values which are not yet spilled, or values which are already restored and used, and *spilled* for values which have been spilled and have not been used yet. _Used_ in this context means that the value itself was actually needed for some computation, not just to spill it. For *active* values, the spill location is optional. For *spilled* values, the value itself is optional. With this extra metadata, we make more educated decisions on when to spill and when to restore a value.

This primarily comes down to restoring lazily. At the moment, we emit `load` instructions directly after a function call, even though those values are not used before the next call (when they need to be spilled again). Instead of emitting `load` instructions, we internally mark the value as *spilled*, with the memory location of the spill. If we end up needing the value, we generate a `load` instruction right before and we update the internal representation to reflect that. At the next spill, we only generate `store` instructions for *active* #a-stack values that do not already have a spill location.

This has the added benefit that it automatically sinks `load` instructions down to their use. It is beneficial to restore values just before they are required, and not earlier, because an early restore means the value is sitting in a register without being used. Since there is a very limited amount of registers, that could lead to needing to use the system stack instead (which is significantly slower), if there are too many values for the amount of registers. Restoring values as late as possible minimises the amount of wasted register space. This is something that #llvm does not do on its own.

=== Benchmark Results
The `astack` benchmark is the only program to see any difference in performance for this optimisation. That is expected, because `list` and `binarytrees` do not make extensive use of the #a-stack, while `astack` does (it is designed to benefit from this optimisation). It is #improvement(bench.heap-64k.astack, "llvm+alias", "llvm+lazy") as fast as non-lazy spilling, and #improvement(bench.heap-64k.astack, "wasm+alias", "wasm+lazy") for Wasm (with a 64 kiB heap). With a larger heap, this improvement is no longer visible on native x86-64, but is still fully there for Wasm.

#figure(
  caption: summary-tables-caption("alias", <ch:alias-metadata>),
  benchmarks-summary-tables("alias", "lazy")
)

== Spilling After Optimisation <ch:spilling-after-optimisation>
One of the advantages of generating spills in an #llvm pass as in @ch:statepoints, is that other passes can run beforehand. The inlining pass is of special interest, since that removes function calls, thereby eliminating the need for spilling and restoring. In particular this should result in a notable performance increase when inlining makes it clear that the #gc is never called (i.e. either the inlined function does not call other functions, or those functions are inlined as well and none of them allocate space on the heap). See @fig:spilling-after-optimisation for an example of where this happens in code where a single #a-stack value (#raw-llvm("%a")) is live.

#[
#show regex("\b(spill|restore|use)\b") : type => text(fill: theme.keyword, type)  
#figure(
  caption: [Pseudo-code for the #llvm output without (left) and with inlining before generating spills (right). The instructions #raw-llvm("spill"), #raw-llvm("restore") and #raw-llvm("use") do not actually exist and are only used as example.],
  grid(columns: 2, gutter: 2em,
    ```llvm
      %a = call ptr @create_heap_value()
      %a.loc = spill %a
      %res = call i64 @f()
      %a.new = restore %a.loc
      use %a.new
    ```,
    ```llvm
      %a = call ptr @create_heap_value()
      
      %res = ; <body of @f>

      use %a
    ```,
  )
) <fig:spilling-after-optimisation>
]

=== Benchmark Results
In the `astack` program, the `isNotEmpty` function is inlined, so no spills are generated.
As expected, this benchmark sees a significant decrease in runtime, for #llvm (#improvement(bench.heap-64k.astack, "llvm+alias", "llvm+pass") faster) and even more for Wasm (#improvement(bench.heap-64k.astack, "wasm+alias", "wasm+pass") faster). We expect that the V8 compiler is able to optimise away even more of the memory operations. This effect is still present, though not as clear, when running with a heap size of 16MiB. The other benchmarks do not see such a good result, or even a performance decrease for `list`. Why this happens is unclear, and we do not rule out a bug in the implementation of the custom #llvm passes.
#figure(
  caption: summary-tables-caption("alias", <ch:alias-metadata>),
  benchmarks-summary-tables("alias", "pass")
)

#let barplot(bm, columns, title: none, max: auto) = {
  let runs = columns.map(group => group.map(name => bm.at(name)))
  let means = runs.map(group => group.map(it => mean(it)))

  let cycle = ((colour: red, hatch: none), (colour: green, hatch: hatched), (colour: blue, hatch: dotted))

  context {
    let offset = 0
    lilaq.diagram(
      xaxis: (
        ticks: columns.flatten()
          .map(align.with(right))
          .map(box.with(width: 53pt))
          .map(rotate.with(-60deg, reflow: true))
          .map(move.with(dx: -13pt))
          .enumerate(),
        ),
      ylabel: "run time (ms)",
      ylim: (0, max),
      title: title,
      ..for (i, group) in columns.enumerate() {
        let positions = range(offset, offset + group.len())
        
        // Group bars together spatially
        // positions = positions.enumerate().map(((i, it)) => {
        //   let offset = i + positions.at(0) - mean(positions)
        //   it - offset * 0.1
        // })
        
        let mean = means.at(i)
        let (fill, stroke) = cell-colour(cycle.at(i).colour, width: 0.5pt)
        let hatch = cycle.at(i).hatch
        fill = if hatch == none { fill } else { hatch(fill: fill, stroke: stroke) }
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

#let barplots(name, columns: (("baseline",), ("llvm", "llvm+static", "llvm+alias", "llvm+lazy", "llvm+pass"), ("wasm", "wasm+static", "wasm+alias", "wasm+lazy", "wasm+pass"))) = {
  let bench-max(bm) = bm.at(name, default: (:)).pairs().filter(((k,_)) => k in columns.flatten()).map(((_,runs)) => calc.max(..runs))
  let max = calc.max(0, ..bench-max(bench.heap-64k), ..bench-max(bench.heap-16M)) * 1.05
  let n-plots = int(name in bench.heap-64k) + int(name in bench.heap-16M)
  grid(columns: (1fr,) * n-plots,
    if name in bench.heap-64k { barplot(bench.heap-64k.at(name), columns, title: [#raw(name) (64kiB)], max: max) },
    if name in bench.heap-16M { barplot(bench.heap-16M.at(name), columns, title: [#raw(name) (16MiB)], max: max) },
  )
}

== Results <ch:benchmark-results>
We now compare all different versions with each other:
- the original Clean compiler _(baseline)_,
- the #abc interpreter _(interpreter)_,
- the un-optimised #llvm implementation as in @ch:shadow-stack, for native x86-64 _(#llvm)_,
- #llvm with static nodes as in @ch:static-nodes _(#llvm+static)_,
- #llvm with static nodes and alias annotations as in @ch:alias-metadata _(#llvm+alias)_,
- #llvm with static nodes, alias annotations and lazy restoring as in @ch:lazy-restore _(#llvm+lazy)_,
- using #llvm passes to spill and restore after inlining as in @ch:spilling-after-optimisation, also includes static nodes and alias annotations _(#llvm+pass)_,
- WebAssembly versions of the above 5 implementations running in V8, the #jit engine used by Node.js.

The bar plots include baseline and x86-64 and Wasm versions of the #clean-llvm output. We explicitly exclude the #abc interpreter from the plots since it is so much slower that the differences between other benchmarks would no longer be visible. While we do also compare between baseline Clean and Wasm, remember that those run in different environments (natively on x86-64 versus in the V8 #jit engine). These are the most relevant comparisons here:

- between the basic #llvm implementation for native x86-64 and Wasm, and the optimised versions _(lazy_ and _pass)_, showing that the improvements from this chapter actually make a difference,
- between the #abc interpreter and the optimised Wasm versions _(lazy_ and _pass)_, showing our advantage over the interpreter,
- between baseline Clean and the optimised #llvm versions for x86-64 and Wasm, showing how close we can get to the performance of the original Clean compiler. Keep in mind that the performance of baseline clean is hard to beat: it is the result of years of Clean-specific low-level optimisations and hand-written assembly code. Additionally, our #llvm output with statepoints on x86-64 still uses a shadow stack instead of walking through the system stack directly. This is unnecessary, but simply not implemented in this thesis.

We observe some general patterns.
Without exception, #clean-llvm (importantly also our Wasm output) is significantly faster than the #abc interpreter in all cases.
While our generated code experiences a slowdown for larger heap sizes, both baseline Clean and the #abc interpreter do not care about the difference in heap size at all. Why those seem unaffected by this, remains a question for further research.

=== Astack
Written with the purpose to show the effects of the optimisations we perform, `astack` succeeds in its goal: for a 64 kiB heap, the basic version is already substantially faster than baseline. But the optimisations stack nicely for this benchmark: the #llvm pass version runs the program twice as fast as baseline Clean. However, as we already saw in @ch:benchmark-consistency, this program is especially impacted by caching behaviour: for a heap of 16 MiB, the #llvm pass version is suddenly around twice as _slow_ as baseline. Even then, Wasm is between #improvement-times(bench.heap-16M.astack, "interpreter", "wasm+pass") and almost #improvement-times(bench.heap-64k.astack, "interpreter", "wasm+pass") faster than the #abc interpreter, depending on the heap size.

#figure(
  benchmark-tables(
    ("64 kiB": bench.heap-64k.astack, "16 MiB": bench.heap-16M.astack),
    title: [`astack`],
    groups: (
      (group: "baseline", prefix: "baseline", columns: ("baseline",)),
      (group: [#llvm], prefix: "llvm", columns: ("llvm", "llvm+static", "llvm+alias", "llvm+lazy", "llvm+pass")),
      (group: "interpreter", prefix: "interpreter", columns: ("interpreter",)),
      (group: [Wasm], prefix: "wasm", columns: ("wasm", "wasm+static", "wasm+alias", "wasm+lazy", "wasm+pass"))
    )
  )
)
#figure(barplots("astack"))

=== List
`list` is the least interesting benchmark of the three, since it does not do much with the #a-stack and it is a very synthetic benchmark. Nevertheless, #llvm on x86-64 is at worst #improvement(bench.heap-16M.list, "llvm+pass", "baseline") slower than baseline, but Wasm is at least #improvement-times(bench.heap-16M.list, "interpreter", "wasm+pass") as fast as the #abc interpreter, which turns into #improvement-times(bench.heap-64k.list, "interpreter", "wasm+alias") in the best case.

Wasm takes about double the time of both #llvm and baseline. We suspect that this may be caused by the amount of indirect function calls that this program does. Since lists in Clean are lazy linked lists, every step of traversing the list is an indirect function call to evaluate a thunk. Remember from @ch:node-entrypoint-indirection that for Wasm, there is an extra indirection in evaluating thunks. This very likely influences the results we see here. In addition, indirect function calls in Wasm require run-time checks to ensure the safety and security guarantees set by the standard, which makes indirect calls a bigger issue for Wasm.

#figure(
  benchmark-tables(
    ("64 kiB": bench.heap-64k.list, "16 MiB": bench.heap-16M.list),
    title: [`list`],
    groups: (
      (group: "baseline", prefix: "baseline", columns: ("baseline",)),
      (group: [#llvm], prefix: "llvm", columns: ("llvm", "llvm+static", "llvm+alias", "llvm+lazy", "llvm+pass")),
      (group: "interpreter", prefix: "interpreter", columns: ("interpreter",)),
      (group: [Wasm], prefix: "wasm", columns: ("wasm", "wasm+static", "wasm+alias", "wasm+lazy", "wasm+pass"))
    )
  )
)
#figure(barplots("list"))

#pagebreak() // TODO: remove?
=== Binarytrees
Finally, we look at `binarytrees`. Out of the three benchmarks we have, this is the most realistic one. This program comes closest to how a 'real' program would behave, so it is important that its performance is good. Looking at the results, it seems that is indeed the case: while #clean-llvm is slower than baseline across the board (which is to be expected), it stays within #improvement(bench.heap-16M.binarytrees, "llvm+pass", "baseline") for x86-64. As for WebAssembly, it manages to keep up with native code as well: the optimised Wasm versions running in Node.js are only #improvement(bench.heap-16M.binarytrees, "wasm+lazy", "baseline") slower than baseline Clean on x86-64. This means that it is about as fast to run this program in the browser using #clean-llvm as it is to run it natively using the original Clean compiler. Compared to the #abc interpreter, our Wasm output runs more than #improvement-times(bench.heap-16M.binarytrees, "interpreter", "wasm+pass") faster.

The different optimisations do not achieve any significant speedup, except for using static nodes which speeds up #llvm on x86-64 #improvement-times(bench.heap-16M.binarytrees, "llvm", "llvm+static", digits: 1) and #improvement-times(bench.heap-16M.binarytrees, "wasm", "wasm+static", digits: 1) for Wasm.

#figure(
  benchmark-tables(
    ("16 MiB": bench.heap-16M.binarytrees),
    title: [`binarytrees`],
    groups: (
      (group: "baseline", prefix: "baseline", columns: ("baseline",)),
      (group: [#llvm], prefix: "llvm", columns: ("llvm", "llvm+static", "llvm+alias", "llvm+lazy", "llvm+pass")),
      (group: "interpreter", prefix: "interpreter", columns: ("interpreter",)),
      (group: [Wasm], prefix: "wasm", columns: ("wasm", "wasm+static", "wasm+alias", "wasm+lazy", "wasm+pass"))
    )
  )
)
#figure(barplots("binarytrees"))



// ================================



= Related Work <ch:related-work>

#chapter-quote(attribution: [Gabbro, Outer Wilds])[It’s the kind of thing that makes you glad you stopped and smelled the pine trees along the way, you know?]

Programming language development is a field where academic research, professional implementation and hobby projects come together. That is also seen in this chapter, which lists all three of these kinds of relevant earlier work.

The idea of a shadow stack as supported by #llvm with its gcroot mechanism is originally described by Henderson~@shadow-stack, although #llvm's implementation differs slightly. Henderson mentions some performance issues with the described implementation, as well as a couple of ways to somewhat (but not completely) alleviate them.

There has been lots of research on the performance of WebAssembly. When compared to native x86-64 code, Wasm is about 1--3#sym.times slower~@wasm-performance-native@wasm-performance-native-ieee. However, it is found to usually run faster than the same program written in JavaScript~@wasm-performance-js. There have even been benchmarks for using Wasm on embedded devices~@wasm-performance-embedded. These show that Wasm is more performant than Micropython and Lua in that scenario, but native code still runs significantly faster.

== WebAssembly for Functional Languages
There are several other functional languages that compile to WebAssembly. Some use #llvm, some use Emscripten (a tool to compile C to Wasm that also uses #llvm internally), and others directly generate Wasm code. They each have a different approach for integrating a garbage collector.

The (unofficial and in development) Elm Wasm compiler uses Emscripten. It has a custom garbage collector specifically for use with Wasm, for which they use a custom stack map~@elm-stack-map, very much like we describe in @ch:shadow-stack. Their #gc is a mark-sweep collector with compaction, so it also moves heap values around in memory like the copying #gc we use for #clean-llvm.

Wasm_of_Ocaml is a compiler from Ocaml to Wasm. It uses multiple proposed WebAssembly extensions, including the #gc extension~@ocaml-wasm. This means that they do not have their own #gc but instead make use of Wasm to manage their memory. There is also Wasocaml~@wasocaml, which is very similar.

Haskell has a WebAssembly back end using #llvm with a custom calling convention that passes everything in registers~@haskell-llvm@haskell-llvm-thesis. They use the same generational #gc as for native targets, and they do not use #llvm to manage #gc roots~@ghc-reddit. There is also research on generating Wasm from Haskell using the MicroHs lightweight Haskell compiler, using WebAssembly's #gc extension~@haskell-wasmgc.

Erlang has an #llvm back end called ErLLVM which uses #llvm's `gcroot` functionality for keeping track of heap values~@erlang-llvm. They note a performance issue about having to explicitly write a sentinel value when a heap reference is no (longer) live. To bypass this issue slightly, they implement more complex code generation, using register colouring for the stack slots. They also use the register pinning method of threading the pinned values through function calls as arguments and return values.

== Garbage-Collected Languages Using LLVM
Julia employs several custom #llvm passes for optimisation and integrating the #gc~@julia-llvm. They use four custom address spaces for tracking which values are garbage-collectable, together with operand bundles and non-integral pointers; the custom address spaces are removed in a later pass which we use in #clean-llvm as well. They use the system stack (with `alloca`) to store heap pointers. However, their garbage collector is non-moving, saving them from having to restore after calls.

The GraalVM Java implementation can use #llvm as 'Native Image' back-end, among others. For its copying garbage collector (enabled by default#footnote[https://www.graalvm.org/latest/reference-manual/native-image/optimizations-and-performance/MemoryManagement/#serial-garbage-collector #accessed(2025, 11, 18)]), it uses #llvm statepoints~@graalvm-llvm to generate stack maps. GraalVM uses #llvm's built-in `rewrite-statepoints-for-gc` pass to generate statepoint instructions. Like we decided to do in @ch:spilling-after-optimisation, they first run optimisations before generating the statepoints.

Google's Go language has multiple compilers based on #llvm: TangoLLVM~@tangollvm uses statepoints, TinyGo~@tinygo is meant for microcontrollers and also supports Wasm compilation, and there is also LLGo~@llgo.

// https://github.com/JuliaLang/julia/blob/master/doc/src/devdocs/llvm.md
// https://github.com/JuliaLang/julia/blob/master/doc/src/devdocs/llvm-passes.md
// https://github.com/JuliaLang/julia/blob/054b2c5ad8678ddf72b96b73d2f096f3200c2a9f/src/llvm-gc-interface-passes.h#L56-L238



// ================================



= Conclusions <ch:conclusions>

#chapter-quote(attribution: [Solanum, Outer Wilds])[If you’ve come here looking for answers, I hope you find them.]

We have integrated the copying garbage collector of the #abc interpreter into #clean-llvm, using both a custom shadow stack approach and using #llvm's statepoints. We improved the performance of both of these implementations by using static nodes and by using #llvm's alias metadata. The custom shadow stack is improved by restoring in a lazy way, and we minimise the amount of spilling further by running #llvm's inlining pass before generating spills. We have evaluated the effect of these optimisations using three benchmarks: `list`, `astack` and `binarytrees`. The `astack` benchmark shows that each of these optimisations have a measurable, positive effect on the runtime. For `binarytrees`, a realistic benchmark program, the output of #clean-llvm manages to come very close to the performance of the existing Clean compiler when running natively on x86-64. More importantly, our Wasm output is more than 7 times faster than the #abc interpreter. These are very promising results for running non-trivial Clean programs on the web.

== Future Work <ch:future-work>
In this thesis we have evaluated our efforts using three benchmark programs. This is of course not a lot of data points, and other programs will behave differently. More programs should be implemented and benchmarked, preferably ones that are academically well-known such as from the Nofib benchmark suite or the Computer Language Benchmarks Game. Most of these non-trivial programs require features or instructions that are not yet implemented in #clean-llvm, so benchmarking these programs is only possible when those are present.

Besides benchmarking the runtime performance, one can also compare the size of the generated code, as well as the amount of memory used and the time taken to compile. Since #llvm is an optimising compiler and the baseline Clean compiler is not, it is to be expected that the compilation time of #clean-llvm will be significantly longer.

We have shown that generating spill/restore instructions in an #llvm pass (using statepoints) can be faster than when done during code generation. However, one of the reasons to use statepoints for this is that it allows us to do away with spilling entirely for targets that support stack unwinding. This has not been implemented, and doing so should result in even better runtime performance for those targets.

The list of optimisations in @ch:performance-improvements is far from complete and there are very likely still some performance improvements possible. Further work could go into generating more efficient #llvm #ir code and giving #llvm more information for optimisations. More ideas for improving runtime performance did not fit within the timeline of this thesis. One of them is that spilling does not need to happen around calls to functions that never run the #gc. Another is based on the fact that the #a-stack pointer returned by a function call is always the same value as the one given as argument to that function call. #llvm does not know that, which potentially hinders some optimising transformations.

Another possible optimisation is based on the fact that the #a-stack values may no longer be in registers at the time they are spilled. If there are not enough registers, some values will be spilled to the system stack by #llvm's code generation. When that happens, spilling one of these values for the #gc requires reading from memory just to place it somewhere else in memory (so that the #gc can read it). This can be solved by spilling as early as possible and restoring as late as possible. This keeps the registers free for other uses. Preliminary results (done by manually altering the generated #llvm #ir) show that this significantly improves performance in cases with lots of local heap references. // ongeveer 0.7x runtime zonder gc

We currently generate spills from statepoints in creation order of the spilled values: older values are spilled first, newer values last. This is not done for any particular reason, but the order is actually important. We want to prevent a situation where spilled values move around on the spilled stack between two function calls. This already works for the custom shadow stack approach since it bases the spill order on where values appear on the #a-stack, which is directly based on the baseline Clean compiler's output. Further research is needed on how to best sort the spills and restores generated from the statepoints.

As the results show, #clean-llvm is sometimes still significantly slower than baseline Clean, also in scenarios where the #a-stack is not used intensively. Our generated code is also much more sensitive to different heap sizes (see @ch:benchmark-consistency). Ultimately, it is necessary to find out where this difference in behaviour comes from and how to get the performance up to the level of baseline Clean and beyond, also with larger heap sizes.



// ================================



#pagebreak(weak: true)
#bibliography("bobliography.yml", style: "association-for-computing-machinery")



// ================================



#show: thesis-appendix

= Benchmark Programs

== `binarytrees` <ch:appendix:binarytrees>

```clean
/* The Computer Language Shootout
   http://shootout.alioth.debian.org/

   contributed by Isaac Gouy (Clean novice)
   corrected by John van Groningen
   modified for Clean-LLVM

   https://web.archive.org/web/20111118030741/http://shootout.alioth.debian.org/u64/program.php?test=binarytrees&lang=clean&id=3
*/

implementation module binarytrees

start :: Int
start
    # stretch`   = max` + 1
    # io         = 0
    #! io        = showItemCheck 0 (bottomup stretch`) io
    #! longLived = bottomup max`
    #! io        = depthloop min` max` io
    #! io        = showItemCheck 0 longLived io
    = io

min` = 4
max` = 16

showItemCheck i a io = io + itemcheck i a

depthloop d m io
    | m < d = io
            = depthloop (d+2) m (io + check)
where
    n = 1 << (m - d + min`)
    check = sumloop n d 0

sumloop :: !Int !Int !Int -> Int
sumloop n d sum
    | 0 < n	= sumloop (n-1) d (sum + check + check`)
            = sum
    where
    check = itemcheck n (bottomup d)
    check` = itemcheck (-1*n) (bottomup d)

:: Tree = TreeNode !Tree !Tree | Nil

bottomup :: !Int -> Tree
bottomup 0 = TreeNode Nil Nil
bottomup d = TreeNode (bottomup (d-1)) (bottomup (d-1))

itemcheck i Nil = i
itemcheck i (TreeNode left right) = i + itemcheck (2*i-1) left - itemcheck (2*i) right

class  (+)  infixl 6 a :: !a !a -> a
class  (-)  infixl 6 a :: !a !a -> a
class  (<)  infix  4 a :: !a !a -> Bool
class  (*)  infixl 7 a :: !a !a -> a

instance + Int
where
    (+) :: !Int !Int -> Int
    (+) a b
        = code inline {
            addI
        }

instance - Int
where
    (-) :: !Int !Int -> Int
    (-) a b
        = code inline {
            subI
        }

instance < Int
where
 (<) :: !Int !Int -> Bool
 (<) a b
    = code inline {
            ltI
    }

instance * Int
where
 (*) :: !Int !Int -> Int
 (*) a b
    = code inline {
            mulI
    }

(<<) infix 7 :: !Int !Int -> Int
(<<) a b
    = code inline {
            shiftl%
    }
```

#pagebreak()
== `list` <ch:appendix:list>

```clean
implementation module list

start :: Int
start = sum (from_to 0 20000000)

from_to :: !Int !Int -> [Int]
from_to x y
    | y < x
        = []
        = [x : from_to (x+1) y]

sum :: ![Int] -> Int
sum xs = accsum 0 xs
where
    accsum :: !Int ![Int] -> Int
    accsum acc [] = acc
    accsum acc [x:xs] = accsum (acc+x) xs

class  (+)  infixl 6 a :: !a !a -> a
class  (<)  infix  4 a :: !a !a -> Bool

instance + Int
where
	(+) :: !Int !Int -> Int
	(+) a b
		= code inline {
			addI
		}

instance < Int
where
 (<) :: !Int !Int -> Bool
 (<) a b
	= code inline {
			ltI
	}

```

#pagebreak()
== `astack` <ch:appendix:astack>

```clean
implementation module astack

:: Node = A Int

start :: Int
start = loop 5000000 0

loop :: !Int !Int -> Int
loop 0 acc = acc
loop x acc = loop (x - 1) (acc + g x)

g :: !Int -> Int
g x =
    let x1  = A 1
        x2  = A 1
        x3  = A 1
        x4  = A 1
        x5  = A 1
        x6  = A 1
        x7  = A 1
        x8  = A 1
        x9  = A 1
        x10 = A 1
        x11 = A 1
        x12 = A 1
        x13 = A 1
        x14 = A 1
        x15 = A 1
        x16 = A 1
    in
        isNotEmpty [x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14, x15, x16] +
        isNotEmpty [x1] +
        isNotEmpty [x2] +
        isNotEmpty [x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14, x15, x16]

isNotEmpty [] = 0
isNotEmpty _  = 1

class  (+)  infixl 6 a :: !a !a -> a
class  (-)  infixl 6 a :: !a !a -> a

instance + Int
where
    (+) :: !Int !Int -> Int
    (+) a b
        = code inline {
            addI
        }

instance - Int
where
    (-) :: !Int !Int -> Int
    (-) a b
        = code inline {
            subI
        }

```
