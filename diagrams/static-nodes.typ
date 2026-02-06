#import "../header.typ": *

#context cetz.canvas(length: 1.5em, {
  import cetz.draw: *

  let weight-factor = text-weight() / 400
  let size-factor = text.size / 11pt

  set-style(stroke: premultiply(text.fill) + 1pt * size-factor)

  let name-length = 2
  let stack-size = 3

  let start-mark = (start: (symbol: "o", fill: premultiply(text.fill), anchor: "center", scale: size-factor))
  let end-mark = (end: (symbol: ">>", fill: premultiply(text.fill), scale: size-factor))

  let obj(x, y, arity, colour, label, radius: 0.3em, ..bodies) = {
    let r = (west: radius)
    if arity == 0 { r = r + (east: radius) }
    rect((x,y), (x+name-length,y+1), radius: r, ..cell-colour(colour, width: 1pt * weight-factor), name: label)
    content((x,y+0.5), anchor: "mid-west", padding: 0.5em, bodies.at(0))
    
    for i in range(arity) {
      let r = if i == arity - 1 { (east: radius) } else { (:) }
      rect((x+name-length+i,y), (x+name-length+1+i,y+1), radius: r, ..cell-colour(colour, width: 1pt * weight-factor), name: label + "-arg" + str(i+1))
      content((x+name-length+i+0.5,y+0.5), anchor: "mid", padding: 5pt, bodies.at(i + 1, default: []))
    }
  }

  let stack = {
    line((0,0), (1,0), stroke: 0.5pt * size-factor)
    line((0,0), (0,stack-size), stroke: 0.5pt * size-factor)
    line((0,stack-size), (0,stack-size+1), stroke: (thickness: 0.5pt * size-factor, dash: "dashed"))
    line((1,0), (1,stack-size), stroke: 0.5pt * size-factor)
    line((1,stack-size), (1,stack-size+1), stroke: (thickness: 0.5pt * size-factor, dash: "dashed"))
  }

  scale(y: -100%)

  rect((2,-0.5), (8.5,8), radius: 0.5em, stroke: (paint: text.fill.transparentize(50%), dash: "dashed"), name: "heap")
  content((rel: (0,0.5), to: "heap.north"))[without static nodes]

  stack
  rect((0,0), (1,1), stroke: 0.5pt * size-factor, name: "3-1")
  rect((0,1), (1,2), stroke: 0.5pt * size-factor, name: "3-2")

  obj(6, 0, 0, red, "nil")[nil]
  obj(2.5, 0, 1, orange, "int")[int][`1`]
  obj(2.5, 2.5, 2, green, "cons")[cons]

  bendy-line("3-1", (rel: (1,0)), (rel: (-1,0), to: "cons.west"), "cons.west", mark: start-mark + end-mark)

  bendy-line("cons-arg1.center", (rel: (0,-1)), (rel: (0.5,1.5), to: "int.west"), (rel: (0.5,0.5), to: "int.west"), mark: start-mark + end-mark)

  bendy-line("cons-arg2.center", (rel: (0,-0.5)), (rel: (0.5,1.5), to: "nil.west"), (rel: (0.5,0.5), to: "nil.west"), mark: start-mark + end-mark)
  
  obj(6, 4, 0, red, "nil")[nil]
  obj(2.5, 4, 1, orange, "int")[int][`1`]
  obj(2.5, 6.5, 2, green, "cons")[cons]

  bendy-line("3-2", (rel: (-2,0), to: "cons.west"), "cons.west", mark: start-mark + end-mark)

  bendy-line("cons-arg1.center", (rel: (0,-1)), (rel: (0.5,1.5), to: "int.west"), (rel: (0.5,0.5), to: "int.west"), mark: start-mark + end-mark)

  bendy-line("cons-arg2.center", (rel: (0,-0.5)), (rel: (0.5,1.5), to: "nil.west"), (rel: (0.5,0.5), to: "nil.west"), mark: start-mark + end-mark)

  // ----------------
  translate((12,0))

  rect((2,-0.5), (7,8), radius: 0.5em, stroke: (paint: text.fill.transparentize(50%), dash: "dashed"), name: "heap")
  content((rel: (0,0.5), to: "heap.north"))[with static nodes]

  stack
  rect((0,0), (1,1), stroke: 0.5pt * size-factor, name: "3-1")
  rect((0,1), (1,2), stroke: 0.5pt * size-factor, name: "3-2")

  obj(9, 0, 0, red, "nil")[nil]
  obj(7.5, -1.5, 1, orange, "int")[int][`1`]
  obj(2.5, 0, 2, green, "cons")[cons]

  line("3-1.center", "cons", mark: start-mark + end-mark)

  bendy-line("cons-arg1.center", (rel: (0,-1.5)), "int.west", mark: start-mark + end-mark)
  line("cons-arg2.center", "nil.west", mark: start-mark + end-mark)
  
  obj(2.5, 2, 2, green, "cons")[cons]

  bendy-line("3-2", (rel: (1,0)), (rel: (-1,0), to: "cons.west"), "cons.west", mark: start-mark + end-mark)

  line((rel: (0.5,2), to: "int.west"), (rel: (0,-1)), stroke: 4pt * size-factor + default(page.fill, white))
  bendy-line("cons-arg1.center", (rel: (0,-1)), (rel: (3,0)), (rel: (0.5,0.5), to: "int.west"), mark: start-mark + end-mark)
  bendy-line("cons-arg2.center", (rel: (0.5,2), to: "nil.west"), (rel: (0.5,0.5), to: "nil.west"), mark: start-mark + end-mark)
})