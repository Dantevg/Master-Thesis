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

    // Baseline Clean
    edge(<abc>, ((), "-|", <x86-orig>), <x86-orig>, "-}>", ..edge-defaults, stroke: luma(30%)),
    edge(<abc>, ((), "-|", <rest-orig>), <rest-orig>, "-}>", ..edge-defaults, stroke: (paint: luma(30%), dash: (2pt, 6pt))),
    edge(<abc>, ((), "-|", <arm-orig>), <arm-orig>, "-}>", ..edge-defaults, stroke: luma(30%), label-pos: 0.7, text(fill: white.transparentize(30%))[Clean code generator]),

    node((rel: (-3.6,2), to: <abc>), stroke: luma(30%), name: <x86-orig>, text(fill: white.transparentize(30%))[x86]),
    node((rel: (-3,2), to: <abc>), stroke: luma(30%), name: <arm-orig>, text(fill: white.transparentize(30%))[Arm]),
    node((rel: (-2.4,2), to: <abc>), stroke: none, name: <rest-orig>, text(fill: white.transparentize(30%))[...]),

    // ABC Interpreter
    edge(<abc>, ((), "-|", <bc>), <bc>, "-}>", ..edge-defaults, stroke: luma(30%), label-pos: 0.7, text(fill: white.transparentize(30%))[#abc interpreter]),
    node((rel: (3,2), to: <abc>), stroke: luma(30%), name: <bc>, text(fill: white.transparentize(30%))[bytecode]),

    pause,

    // Clean-LLVM
    edge(<abc>, <llvm>, "-}>", ..edge-defaults, label-pos: 0.4)[#clean-llvm],
    node((rel: (0,1), to: <abc>), ..cell-colour-transparent(green, width: 1pt * weight-factor), name: <llvm>)[#llvm #ir],

    pause,

    edge((rel: (0,0.4), to: <llvm>), ((), "-|", (<wasm>)), <wasm>, "-}>"),
    edge((rel: (0,0.4), to: <llvm>), ((), "-|", (<arm>)), <arm>, "-}>"),
    edge((rel: (0.6,0.4), to: <llvm>), ((), "-|", (<rest>)), <rest>, "-}>", stroke: (dash: (2pt, 6pt))),
    edge(<llvm>, <x86>, "-}>", ..edge-defaults, label-pos: 0.4)[Clang],

    node((rel: (-0.6,1), to: <llvm>), ..cell-colour-transparent(blue, width: 1pt * weight-factor), name: <wasm>)[Wasm],
    node((rel: (0,1), to: <llvm>), ..cell-colour-transparent(blue, width: 1pt * weight-factor), name: <x86>)[x86],
    node((rel: (0.6,1), to: <llvm>), ..cell-colour-transparent(blue, width: 1pt * weight-factor), name: <arm>)[#arm],
    node((rel: (1.2,1), to: <llvm>), stroke: none, name: <rest>)[...],
  )
}