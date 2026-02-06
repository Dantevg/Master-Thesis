#import "../header.typ": *

#let dashes(phase: 0pt) = (dash: (array: (3pt, 3pt), phase: phase))

#context cetz.canvas(length: 1.5em, {
  import cetz.draw: *

  set-style(stroke: text.fill)

  let heap-size = 8
  let edge-radius = 0.5

  let semispaces(active) = {
    grid((0,0), (heap-size*2,1), stroke: 0.5pt + gray)
    rect(((1-active)*heap-size,0), ((2-active)*heap-size,1), fill: hatched(), stroke: 0pt)
    line((heap-size,0), (heap-size,1))
    content((heap-size/2,-0.1), anchor: "north")[ss 1]
    content((heap-size + heap-size/2,-0.1), anchor: "north")[ss 2]
  }

  let obj(pos, size, colour, label, body) = {
    rect((pos,0), (pos+size,1), radius: 3pt, ..cell-colour-transparent(colour), name: label)
    content((pos+size/2,0.5), body)
  }

  let hp(pos) = line((pos+0.5,1.5), (pos+0.5,1), mark: (end: ">>", fill: text.fill, stroke: 0pt), stroke: 0.5pt)

  let transition(body) = {
    arc-through((heap-size*2+0.5,0.25), (heap-size*2+1.5,-1), (heap-size*2+0.5,-2.25), mark: (end: ">>", fill: text.fill, stroke: 0pt))
    content((heap-size*2+1.5,-1), box(fill: default(page.fill, white), inset: 2pt, body))
  }

  semispaces(0)
  obj(0, 3, red, "1-1")[object 1]
  obj(3, 3, orange, "2-1")[object 2]
  hp(6)

  transition[1.~collect]
  set-origin((0,-3))

  semispaces(1)
  obj(heap-size+0, 3, orange, "2-2")[object 2]
  hp(heap-size+3)

  transition[2.~allocate]
  set-origin((0,-3))

  semispaces(1)
  obj(heap-size+0, 3, orange, "2-3")[object 2]
  obj(heap-size+3, 3, green, "3-1")[object 3]
  hp(heap-size+6)

  line("1-1.south", (rel: (0,-0.75)), stroke: (paint: gray, ..dashes(phase: -2pt)))
  content((rel: (0, -0.25)), emoji.bin)

  bendy-line((rel: (0.5,0), to: "2-1.south"), (rel: (0,-1)), (rel: (0,1), to: "2-2.north"), "2-2.north", stroke: (paint: gray, ..dashes()), mark: (end: (symbol: ">>", fill: gray, stroke: 0pt)))
  content((rel: (3,-1), to: "2-1.south"), box(fill: default(page.fill, white), inset: 2pt, text(fill: gray, "copy")))

  content((rel: (0, 0.5), to: "3-1.north"), emoji.sparkles)
})