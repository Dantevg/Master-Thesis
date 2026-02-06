#import "../header.typ": *

#context cetz.canvas(length: 1.5em, {
  import cetz.draw: *

  let weight-factor = text-weight() / 400
  let size-factor = text.size / 11pt

  set-style(stroke: premultiply(text.fill) + 1pt * size-factor * weight-factor)

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
    line((0,0), (1,0), stroke: 0.5pt * size-factor * weight-factor)
    line((0,0), (0,stack-size), stroke: 0.5pt * size-factor * weight-factor)
    line((0,stack-size), (0,stack-size+1), stroke: (thickness: 0.5pt * size-factor * weight-factor, dash: "dashed"))
    line((1,0), (1,stack-size), stroke: 0.5pt * size-factor * weight-factor)
    line((1,stack-size), (1,stack-size+1), stroke: (thickness: 0.5pt * size-factor * weight-factor, dash: "dashed"))
  }

  scale(y: -100%)

  stack
  rect((0,0), (1,1), stroke: 0.5pt * size-factor * weight-factor, name: "1-1")

  obj(2.5, 0, 0, red, "nil")[nil]
  line("1-1.center", "nil.west", mark: start-mark + end-mark)

  // ----------------
  translate((9, 0))
  line((-3,2), (-2,2), stroke: gray, fill: gray, mark: (end: ">>"))
  stack
  rect((0,0), (1,1), stroke: 0.5pt * size-factor * weight-factor, name: "2-1")
  rect((0,1), (1,2), stroke: 0.5pt * size-factor * weight-factor, name: "2-2")

  obj(2.5, 0, 0, red, "nil")[nil]
  line("2-1.center", "nil.west", mark: start-mark + end-mark)

  obj(2.5, 1.5, 1, orange, "int")[int][`1`]
  bendy-line("2-2", (rel: (0.75,0)), (rel: (-0.75,0), to: "int.west"), "int.west", mark: start-mark + end-mark)

  // ----------------
  translate((10, 0))
  line((-3,2), (-2,2), stroke: gray, fill: gray, mark: (end: ">>"))
  stack
  rect((0,0), (1,1), stroke: 0.5pt * size-factor * weight-factor, name: "3-1")

  obj(2.5, 0, 0, red, "nil")[nil]
  obj(2.5, 1.5, 1, orange, "int")[int][`1`]
  obj(2.5, 4, 2, green, "cons")[cons]

  bendy-line("3-1", (rel: (1,0)), (rel: (-1,0), to: "cons.west"), "cons.west", mark: start-mark + end-mark)

  bendy-line("cons-arg1.center", (rel: (0,-1)), (rel: (0.5,1.5), to: "int.west"), (rel: (0.5,0.5), to: "int.west"), mark: start-mark + end-mark)

  bendy-line("cons-arg2.center", (rel: (1.5,0), to: "nil.east"), "nil.east", mark: start-mark + end-mark)
})