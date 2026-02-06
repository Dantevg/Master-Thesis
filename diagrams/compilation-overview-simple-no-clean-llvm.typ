#import "../header.typ": *
#import "@preview/touying:0.6.1": *

#let diagram = touying-reducer.with(
  reduce: fletcher.diagram,
  cover: fletcher.hide,
)

#{
  let edge-defaults = (label-side: center, label-fill: black, crossing: true, crossing-fill: black)

  let weight-factor = 500 / 400
  let size-factor = 17.6pt / 11pt
  
  diagram(
    node-stroke: 1pt * size-factor,
    node-corner-radius: 5pt,
    node-shape: rect,
    edge-stroke: 1pt * size-factor + luma(90%),
    edge-corner-radius: 5pt * size-factor,
    spacing: 3em,
    node((0,0), ..cell-colour-transparent(red, width: 1pt * weight-factor), name: <clean>)[Clean],
    edge(<clean>, <abc>, "-}>", ..edge-defaults, label-pos: 0.4)[Clean compiler],
    node((rel: (0,1), to: <clean>), ..cell-colour-transparent(orange, width: 1pt * weight-factor), name: <abc>)[#abc],

    pause,

    // Baseline Clean
    edge(<abc>, ((), "-|", <x86-orig>), <x86-orig>, "-}>", ..edge-defaults),
    edge(<abc>, ((), "-|", <rest-orig>), <rest-orig>, "-}>", ..edge-defaults, stroke: (dash: (2pt, 6pt))),
    edge(<abc>, ((), "-|", <arm-orig>), <arm-orig>, "-}>", ..edge-defaults, label-pos: 0.7)[Clean code generator],

    node((rel: (-2.2,1), to: <abc>), ..cell-colour-transparent(blue, width: 1pt * weight-factor), name: <x86-orig>)[x86],
    node((rel: (-1.6,1), to: <abc>), ..cell-colour-transparent(blue, width: 1pt * weight-factor), name: <arm-orig>)[Arm],
    node((rel: (-1,1), to: <abc>), stroke: none, name: <rest-orig>)[...],

    pause,

    // ABC Interpreter
    edge(<abc>, ((), "-|", <bc>), <bc>, "-}>", ..edge-defaults, label-pos: 0.7)[#abc interpreter],
    node((rel: (1,1), to: <abc>), ..cell-colour-transparent(purple), name: <bc>)[bytecode],

    pause,

    // Clean-LLVM
    edge(<abc>, <llvm>, "-}>", ..edge-defaults)[#clean-llvm],
    node((rel: (0,1.5), to: <abc>), stroke: none, name: <llvm>)[?],
  )
}