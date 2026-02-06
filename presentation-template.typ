#import "@preview/touying:0.6.1": *
#import themes.simple: *

#let theme = (
  red: rgb("#e3000b"),
  poppy: rgb("#ff424b"),
  ladybug: rgb("#be311e"),
  berry: rgb("#8f2011"),
  maroon: rgb("#730e04"),
  mahogany: rgb("#4a0004")
)

#let em(emoji) = box(inset: (x: 0em, y: -0.5em), baseline: -0.5em, emoji)

#let title-slide(config: (:), ..args) = touying-slide-wrapper(self => {
  show heading: set text(fill: white, weight: "black")
  set text(fill: theme.mahogany)
  let h = context utils.current-heading()
  touying-slide(
    self: self,
    ..args.named(),
    config: utils.merge-dicts(
      config,
      config-common(freeze-slide-counter: true),
      config-page(fill: theme.red)
    ),
    align(left + horizon, h + v(.5em) + args.pos().sum(default: none))
    + place(bottom + left, dy: 20pt, image("img/top-software.png", height: 100pt))
    + place(bottom + right, dy: 20pt, image("img/ru-zwart.png", height: 100pt))
  )
})

#let speaker-note-orig = speaker-note
#let speaker-note(body) = speaker-note-orig({
  set text(size: 0.9em)
  body
})

#let presentation(show-notes: false, dark: true, body) = {
  show: simple-theme.with(
    primary: theme.poppy,
    subslide-preamble: block(
      below: 1.5em,
      text(1.2em, weight: "bold", utils.display-current-heading(level: 2), fill: theme.poppy),
    ),
    footer-right: context utils.slide-counter.display(),
    config-common(show-notes-on-second-screen: show-notes)
  )

  set page(fill: black) if dark
  set text(fill: white.transparentize(10%), weight: "medium") if dark

  set text(font: "Atkinson Hyperlegible Next", size: 22pt, lang: "en", region: "gb", number-type: "old-style", discretionary-ligatures: true)

  show smallcaps: set text(font: "Noto Sans", top-edge: 2/3 * 1em)
  show heading: set text(weight: "black", fill: white)

  set raw(theme: "Monokai Dark.tmTheme")
  show raw: set text(font: "JetBrains Mono")
  show raw.where(block: true): set text(size: 0.9em)

  show raw.where(lang: "llvm"): it => {
    set text(weight: "semibold")
    show regex("\(|\)|\{|\}|\[|\]|,|="): set text(fill: luma(70%))
    show regex("\b(define|call|addrspace|store|to|load)\b"): set text(fill: theme.poppy.lighten(30%))
    show regex("\b(ptr|heapptr|token)\b"): set text(fill: aqua.lighten(50%), style: "italic")
    show regex("\b(i64|i32)\b"): set text(fill: aqua.lighten(50%))
    show regex("\b\d+\b"): set text(fill: purple.lighten(70%))
    show regex("\"[^\"]*\""): set text(fill: green.lighten(70%))
    // show regex("[@%][\w.]+"): set text(fill: white)
    it
  }

  set figure(gap: 1em)
  show figure.caption: it => { block(inset: (x: 20pt), align(left, it)) }
  show figure: set text(size: 0.7em)

  body
}