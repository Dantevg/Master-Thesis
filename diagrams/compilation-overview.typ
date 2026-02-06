#import "../header.typ": *

#context {
  let edge-defaults = (label-side: center, label-fill: page.fill, crossing: true, crossing-fill: page.fill)
  diagram(
    node-stroke: 1pt,
    node-corner-radius: 5pt,
    node-shape: rect,
    edge-stroke: 1pt + text.fill,
    edge-corner-radius: 5pt,
    spacing: 4em,
    node((0,0), ..cell-colour-transparent(red), name: <clean>)[Clean \ (`.icl`, `.dcl`)],
    edge(<clean>, <abc>, "-}>", ..edge-defaults, label-pos: 0.44)[`cocl`],
    node((rel: (1,0), to: <clean>), ..cell-colour-transparent(orange), name: <abc>)[#abc \ (`.abc`)],
    edge(<abc>, <llvm>, "-}>", ..edge-defaults, corner: right, label-pos: 0.25)[`abc2bc`],
    node((rel: (1,-2), to: <abc>), ..cell-colour-transparent(green), name: <llvm>)[#llvm #ir \ (`.ll`, `.bc`)],
    
    edge((rel: (0.5,0.5), to: <llvm>), ((), "|-", (<rest>)), <rest>, "--}>"),
    node((rel: (1,0.9), to: <llvm>), stroke: none, name: <rest>)[...],
    
    edge((rel: (0.5,0), to: <llvm>), ((), "|-", (<wasm>)), <wasm>, "-}>"),
    node((rel: (1,-0.6), to: <llvm>), ..cell-colour-transparent(blue), name: <wasm>)[Wasm \ (`.wasm`)],
    
    edge((rel: (0.5,0), to: <llvm>), ((), "|-", (<arm>)), <arm>, "-}>"),
    node((rel: (1,0.5), to: <llvm>), ..cell-colour-transparent(blue), name: <arm>)[#arm],
    
    edge(<llvm>, <x86>, "-}>", ..edge-defaults, label-pos: 0.4)[`clang`],
    node((rel: (1,0), to: <llvm>), ..cell-colour-transparent(blue), name: <x86>)[x86],
  
    edge(<abc>, <bc>, "-}>", ..edge-defaults, corner: left, label-pos: 0.4, stroke: gray, align(center)[`abcopt`\ `bcgen`\ `bclink`]),
    node((rel: (0.75,1.5), to: <abc>), stroke: gray, name: <bc>)[bytecode \ (`.bc`)],
    edge(<bc>, <pbc>, "-}>", ..edge-defaults, label-pos: 0.45, stroke: gray)[`bcprelink`],
    node((rel: (1.25,0), to: <bc>), stroke: gray, name: <pbc>)[prelinked \ bytecode \ (`.pbc`)],
  
    node((rel: (2,-0.4), to: <abc>), stroke: gray, name: <x86-orig>)[x86],
    edge((rel: (1.5,0), to: <abc>), ((), "|-", <x86-orig.west>), <x86-orig>, "-}>", ..edge-defaults, stroke: gray),
    node((rel: (2,0.4), to: <abc>), stroke: none, name: <rest-orig>)[...],
    edge((rel: (1.5,0), to: <abc>), ((), "|-", <rest-orig.west>), <rest-orig>, "--}>", ..edge-defaults, stroke: gray),
    node((rel: (2,0), to: <abc>), stroke: gray, name: <arm-orig>)[#arm],
    edge(<abc>, <arm-orig>, "-}>", ..edge-defaults, label-pos: 0.78, stroke: gray)[`cg`],
  
    node(enclose: ((0.75,-2.9), (3.5,-0.9)), stroke: (paint: text.fill, thickness: 0.5pt, dash: "dashed")),
    node(enclose: ((1.5,-0.6), (3.5,0.6)), stroke: (paint: text.fill, thickness: 0.5pt, dash: "dashed")),
    node(enclose: ((0.75,0.9), (3.5,2)), stroke: (paint: text.fill, thickness: 0.5pt, dash: "dashed")),
  
    edge((3.6,-2.9), (3.6,-0.9), stroke: 0pt, label-side: left, label-angle: -90deg)[#clean-llvm],
    edge((3.6,-0.6), (3.6,0.6), stroke: 0pt, label-side: left, label-angle: -90deg)[baseline Clean],
    edge((3.6,0.9), (3.6,2), stroke: 0pt, label-side: left, label-angle: -90deg)[#abc interpreter],
  )
}