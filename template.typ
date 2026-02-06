#import "@preview/hydra:0.6.2": hydra
#import "@preview/zebraw:0.6.0": *

#let smallpage(body) = page(header: none, footer: none, margin: (x: 20%, bottom: 3.5cm), body)

#let abstract(body) = smallpage(
  heading(level: 1, numbering: none, outlined: false, bookmarked: true)[Abstract] + body
)

#let contents = smallpage(outline(depth: 3))

#let theme = (
  comment: rgb("74747c"),
  escape: rgb("1d6c76"),
  math: rgb("198810"),
  operator: rgb("1d6c76"),
  list: rgb("8b41b1"),
  label: rgb("1d6c76"),
  keyword: rgb("d73948"),
  type: rgb("b60157"), // rgb("d73948")
  constant: rgb("b60157"), // eastern
  string: rgb("198810"),
  name: rgb("4b69c6"),
  macro: rgb("16718d"),
  annotation: rgb("301414"),
  other: rgb("8b41b1"),
  inserted: rgb("198810"),
  deleted: rgb("d73948"),
  key: rgb("4b69c6"),
  value: rgb("198810"),
)

#let abc-boolean = text.with(fill: theme.keyword)
#let abc-instruction = text.with(fill: theme.label)
#let abc-type = text.with(fill: theme.type)
#let abc-label = text.with(fill: theme.label)
#let abc-number = text.with(fill: theme.constant)
#let abc-comment = text.with(fill: theme.comment)
#let abc-annotation = text.with(fill: theme.comment)

#let raw-clean(it) = raw(lang: "clean", it)
#let raw-abc(it) = raw(lang: "abc", it)
#let raw-llvm(it) = raw(lang: "llvm", it)
#let raw-wasm(it) = raw(lang: "wat", it)

#let syntax-abc = it => {
  show regex("\b(TRUE|FALSE)\b") : abc-boolean
  show regex("\b\s\w[\w.]+") : abc-instruction
  show regex("\bi\b") : abc-type
  show regex("\n[\w.]+\n") : abc-label
  show regex("\s\d+\b") : abc-number
  show regex(";.*") : abc-comment
  show regex("(?m)^\..*") : abc-annotation
  it
}

#let inline-code(it) = box(stroke: 0.5pt + black.transparentize(75%), radius: 2pt, inset: (x: 2pt), outset: (x: 0pt, y: 3pt), it)

#let chapter-quote(attribution: none, body) = place(top + right, dy: 5em,
  block(width: 60%,
    quote(
      block: true,
      attribution: text(fill: luma(30%), size: 0.9em, attribution),
      text(style: "italic", fill: luma(30%), size: 0.9em, body)
    )
  )
)

#let is-starting-page() = {
  let next = query(selector(heading.where(level: 1)).after(here())).filter(it => it.location().page() == here().page()).first(default: none)
  next != none and next.location().page() == here().page()
}

// Aliased because it's shadowed by the #thesis argument
#let title-elem = title

#let thesis(
  title: "",
  description: "",
  author: "",
  date: none,
  supervisors: (),
  body,
) = {
  // Set the document's basic properties.
  set document(title: title, author: author.name, description: description, date: date)
  let header-mono(body) = text(font: "Noto Sans Mono", size: 0.85em, body)
  let subheading = smallcaps(all: true, context hydra(1))
  let page-number = context counter(page).display()
  
  set page(
    paper: "a4",
    numbering: "i",
    number-align: right,
    header: counter(footnote).update(0)
      + context if not is-starting-page() { header-mono(subheading) + h(1fr) + header-mono(page-number) + line(length: 100%, stroke: 0.5pt) },
    footer: none,
    margin: (top: 3cm, bottom: 2cm), // effectively shifts page down by 0.5cm
  )
  set text(font: "Libertinus Serif", lang: "en", region: "gb", number-type: "old-style", hyphenate: false, discretionary-ligatures: true)
  set heading(numbering: "1.1 ", supplement: [§])
  show heading: set block(above: 1.5em, below: 1em)
  show heading: set text(size: 1.2em, number-type: "lining")

  show heading.where(level: 1, supplement: [§]): set heading(supplement: [chapter])
  show heading.where(level: 1): set text(size: 1.5em, font: "PT Sans")
  show heading.where(level: 1): set block(inset: (top: 1.5em, bottom: 1.5em))
  show heading.where(level: 1): set par(spacing: 0.5em)
  show heading.where(level: 1): it => {
    // counter(footnote).update(0)
    block(
      par(text(weight: "black", fill: gray, size: 3em, if (counter(heading).get() == (0,) or counter(heading).get().len() > 1) {""} else { counter(heading).display() }))
      + it.body
    )
  }
  show heading.where(level: 1, outlined: true): it => pagebreak(weak: true) + it

  show heading.where(level: 4): set text(
    size: 11pt,
    // weight: "regular",
    // style: "italic",
  )
  show heading.where(level: 4): it => it.body + [.] + sym.space

  show title-elem: set text(size: 1.5em, font: "PT Sans")
  set figure(gap: 1em)
  show figure.caption: set text(size: 0.9em)
  show figure.caption: it => { block(inset: (x: 20pt), align(left, it)) }

  // Lower-case figure supplement references
  let in-ref = state("in-ref", false)
  show ref: it => in-ref.update(true) + it + in-ref.update(false)
  let sup(ref) = context if in-ref.get() { lower(ref) } else { ref }
  show figure.where(kind: raw): set figure(supplement: sup("Listing"))
  show figure.where(kind: image): set figure(supplement: sup("Figure"))
  show figure.where(kind: table): set figure(supplement: sup("Table"))

  show figure.where(kind: table): set figure.caption(position: top)

  show heading.where(supplement: [appendix]): set heading(numbering: (..nums) => {
    context if in-ref.get() { smallcaps(all: true, numbering("A1", ..nums)) } else { numbering("A1 ", ..nums) }
  })

  show outline.entry: it => link(
    it.element.location(),
    it.indented(it.prefix(), it.inner(), gap: 1em)
  ) // default outline entry but with larger gap between numbering and name
  show outline.entry.where(level: 1): set block(above: 1.5em)
  show outline.entry.where(level: 1): set text(weight: "bold")
  set outline.entry(fill: line(length: 100%, stroke: black.transparentize(75%)))

  // To be able to refer to enum items
  set enum(numbering: (..it) => {
    counter("enum").update(it.pos())
    numbering("1.", ..it)
  })
  
  show ref: it => {
    let el = it.element
    if el != none and el.func() == text {
      let sup = if it.supplement == auto [item~] else if it.supplement == [] [] else [#it.supplement~]
      link(el.location(), [#sup#numbering("1", ..counter("enum").at(el.location()))])
    } else {
      it
    }
  }

  page(header: none, footer: none)[
    #v(80pt)
    #text(size: 1.5em, smallcaps[Master's Thesis Software Science])
    #v(3em)
    #title-elem()
    #v(2em)
    #text(size: 2em, description)
    #v(2em)
    #author.name \
    #raw(author.email) \
    #author.s-number
    #v(1em)
    #date.display("[day padding:none] [month repr:long] [year]")

    #v(2em)

    #align(right)[
      _First supervisor_ \
      #supervisors.first
      #v(1em)
      _Daily supervisor_ \
      #supervisors.company
      #v(1em)
      _Second reader_ \
      #supervisors.second
    ]

    #place(bottom + center, grid(
      columns: (auto, 1fr, auto),
      align: (left, left, right),
      image("img/top-software.png", height: 45pt),
      h(15pt) + text(baseline: -15pt, size: 1.5em, font: "PT Sans", weight: "medium", fill: luma(20%), ligatures: false)[TOP Software],
      image("img/ru.svg", height: 45pt),
    ))
  ]

  // Main body.
  set par(justify: true, justification-limits: (tracking: (min: -0.02em, max: 0.02em)))

  show: zebraw-init.with(
    extend: false,
    background-color: (luma(98%), luma(96%)),
    highlight-color: blue.lighten(85%),
    numbering-separator: true,
    comment-color: blue.lighten(75%),
    comment-flag: "",
    comment-font-args: (
      font: "Libertinus Serif",
      size: 1.1em,
    ),
  )
  show: zebraw

  set raw(syntaxes: "clean.sublime-syntax")

  show raw: set text(size: 0.9em)
  show raw.where(block: true): set text(size: 0.9em)
  show raw: set text(discretionary-ligatures: false)

  show raw.where(lang: "abc"): syntax-abc

  show raw.where(lang: "llvm"): it => {
    show regex("\b(i(\d+)|ptr)\b") : type => text(fill: theme.type, type)
    show regex("%[A-Za-z0-9_.]+\b") : def => text(fill: theme.name, def)
    show regex("@[A-Za-z0-9_.]+\b") : def => text(fill: theme.other, def)
    show regex(".+:") : def => text(fill: theme.label, def)
    show regex("\s\d+\b") : num => text(fill: theme.constant, num)
    show regex(";;.*") : comment => text(fill: theme.comment, comment)
    it
  }

  show raw.where(lang: "wasm"): it => {
    show regex("\b(block|type|func|param|result)\b") : keyword => text(fill: theme.keyword, keyword)
    show regex("\bi\d+\b") : type => text(fill: theme.type, type)
    show regex("\$\.\w+\b") : def => text(fill: theme.other, def)
    show regex("\s\d+\b") : num => text(fill: theme.constant, num)
    show regex(";;.*") : comment => text(fill: theme.comment, comment)
    show regex("\(;[^;]+;\)") : comment => text(fill: theme.comment, comment)
    it
  }

  body
}

#let thesis-body(body) = {
  show link: set text(fill: blue.darken(50%))
  set page(numbering: "1")
  counter(page).update(1)
  body
}

#let thesis-appendix(body) = {
  set heading(numbering: "A1 ", supplement: [appendix])
  counter(heading).update(0)
  body
}