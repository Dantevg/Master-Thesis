/*
  This file contains general helper functions, as well as some functions that are specific to this thesis.
*/

#import "@preview/cetz:0.4.2"
#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
#import "@preview/lilaq:0.5.0"
#import "@preview/modpattern:0.1.0": modpattern

// Smallcaps acronyms
#let abc = smallcaps[abc]
#let adt = smallcaps[adt]
#let api = smallcaps[api]
#let arm = [Arm]
#let llvm = smallcaps[llvm]
#let clean-llvm = [Clean-#llvm]
#let cpu = smallcaps[cpu]
#let cv = smallcaps[cv]
#let gc = smallcaps[gc]
#let hnf = smallcaps[hnf]
#let ir = smallcaps[ir]
#let jit = smallcaps[jit]
#let l1 = smallcaps[l1]
#let l2 = smallcaps[l2]
#let ssa = smallcaps[ssa]
#let ui = smallcaps[ui]

#let a-stack = [*A* stack]
#let b-stack = [*B* stack]
#let c-stack = [*C* stack]

// Display a date as "30 January 2026"
#let date(year, month, day) = datetime(year: year, month: month, day: day).display("[month repr:short]. [day padding:none], [year]")

// Display "(accessed: 30 January 2026)" for links
#let accessed(year, month, day) = [(accessed:~#date(year, month, day))]

// Display "[TODO]" or "[TODO: body]" with a highlight colour
#let todo(..body) = if body.pos() != () {
  set text(lang: "nl")
  highlight(fill: teal.transparentize(50%))[[TODO: #body.at(0)]]
} else {
  highlight(fill: fuchsia.transparentize(50%))[[TODO]]
}

// Numerical weights for names
#let text-weights = (
  thin: 100,
  extralight: 200,
  light: 300,
  regular: 400,
  medium: 500,
  semibold: 600,
  bold: 700,
  extrabold: 800,
  black: 900,
)

// The current text weight as a number
#let text-weight() = {
  if type(text.weight) == int {
    text.weight
  } else {
    text-weights.at(text.weight, default: 400)
  }
}

// Typst colours in oklch space
#let colours = (
  navy: oklch(23.81%, 0.713, 252.01deg),
  blue: oklch(56.22%, 0.17728, 253.7095deg),
  aqua: oklch(84.72%, 0.1011, 225.43deg),
  teal: oklch(77.13%, 0.1192, 194.97deg),
  eastern: oklch(64.0%, 0.1026, 208.48deg),
  purple: oklch(55.24%, 0.2577, 321.47deg),
  fuchsia: oklch(64.66%, 0.2739, 340.98deg),
  maroon: oklch(41.15%, 0.1522, 357.58deg),
  red: oklch(65.95%, 0.2272, 28.44deg),
  orange: oklch(74.02%, 0.179468, 53.4788deg),
  yellow: oklch(89.67%, 0.185062, 97.445deg),
  olive: oklch(61.64%, 0.1081, 161.32deg),
  green: oklch(73.96%, 0.2204, 144.29deg),
  lime: oklch(87.3%, 0.2472, 148.84deg),
)

// Return a default value if `auto` is passed
#let default(value, default) = if value == auto { default } else { value }

#let _type = type
// Unpack a value out of a dictionary, while also allowing the value itself to be passed already unpacked
// Example: these both return `white`
//   unpack((fill: white), "fill", type: color)
//   unpack(white, "fill", type: color)
#let unpack(obj, key, type: none, default: none) = {
  if type != none and _type(obj) == type {
    obj
  } else if _type(obj) == dictionary {
    obj.at(key, default: default)
  } else {
    default
  }
}

// Premultiply alpha with the background colour of the page
// Must be called in a context block
#let premultiply(colour) = {
  let (_, _, _, a) = rgb(colour).components()
  color.mix((colour.opacify(100%), a), (default(page.fill, white), 100% - a), space: rgb)
}

// Semi-transparent fill and stroke with the given colour
#let cell-colour-transparent(base, width: 1pt) = (
  fill: base.transparentize(70%).desaturate(40%),
  stroke: width + base.desaturate(60%).darken(30%),
)

// Fully opaque fill and stroke with the given colour
// Looks the same as cell-colour-transparent, except that things behind it do not show
#let cell-colour(base, width: 1pt) = {
  let colour = cell-colour-transparent(base, width: width)
  colour.fill = premultiply(colour.fill)
  colour
}

// Diagonal line hatched fill
#let hatched(fill: none, stroke: 0.5pt + gray, scale: 5pt, flip: false) = modpattern(
  background: fill,
  (scale, scale),
  place(rotate(if flip { 90deg } else { 0deg }, line(start: (0%, 100%), length: scale * 1.5, angle: -45deg, stroke: stroke)))
)

// Dotted fill
#let dotted(fill: none, stroke: 1pt + gray, scale: 5pt) = tiling(
  size: (scale, scale),
  // background
  place(square(fill: fill, stroke: none))
  // main circle
  + place(center + horizon, dx: scale/2, dy: scale/2, circle(radius: stroke.thickness*1.5, fill: stroke.paint, stroke: none))
  // top-left corner
  + place(center + horizon, circle(radius: stroke.thickness*1.5, fill: stroke.paint, stroke: none))
  // top-right corner
  + place(center + horizon, dx: scale, circle(radius: stroke.thickness*1.5, fill: stroke.paint, stroke: none))
  // bottom-left corner
  + place(center + horizon, dy: scale, circle(radius: stroke.thickness*1.5, fill: stroke.paint, stroke: none))
  // bottom-right corner
  + place(center + horizon, dx: scale, dy: scale, circle(radius: stroke.thickness*1.5, fill: stroke.paint, stroke: none))
)

// Line with rounded corners
// Mostly drop-in replacement for `line`
// Start and end marks are given as `mark: (start: (...), end: (...))`
#let bendy-line(start, ..args) = cetz.draw.group(ctx => {
  let style = args.named()
  let mark = style.remove("mark", default: (:))
  let mark-start = mark.at("start", default: none)
  let mark-end = mark.at("end", default: none)
  let radius = style.remove("radius", default: 0.5)
  
  cetz.draw.move-to(start)
  
  let (ctx, prev, ..points) = cetz.coordinate.resolve(ctx, start, ..args.pos())
  
  for (i, (p, next)) in points.windows(2).enumerate() {
    let direction = cetz.vector.norm(cetz.vector.sub(p, prev))
    let angle-start = cetz.vector.angle2(prev, p)
    let angle-stop = cetz.vector.angle2(p, next)
    let angle-diff = angle-stop - angle-start

    // Seems kinda arbitrary but this works so idk
    if angle-diff > 180deg { angle-diff = 180deg - angle-diff }
    if angle-diff < -180deg { angle-diff = -180deg - angle-diff }
    if angle-diff < 0deg { angle-start = 180deg + angle-start }
    
    let offset = calc.tan(calc.abs(angle-diff) / 2)
    let p-pre = cetz.vector.add(p, cetz.vector.scale(direction, -radius * offset))
    prev = p
    
    cetz.draw.line((), p-pre, ..style, mark: if i == 0 { (start: mark-start) } else { (:) })
    cetz.draw.arc((), start: angle-start - 90deg, delta: angle-diff, radius: radius, ..style)
  }
  
  if points.len() > 0 {
    cetz.draw.line((), points.last(), ..style, mark: (end: mark-end))
  }
})

// Display a number with thousands separators and a given number of decimal digits
#let num(n, digits: auto, unit: none, decsep: ".", thousandsep: sym.space.narrow.nobreak) = {
  let string = ""

  let n = if digits == auto { n } else { calc.round(n, digits: digits) }
  let n = str(n).replace("−", "-").replace(" ", "")
  let (int-part, ..dec-part) = n.split(decsep)
  let int-list = int-part.clusters()
  let dec-list = dec-part.at(0, default: "").clusters()
  
  for (i, n) in int-list.enumerate() {
    string += str(n)
    if calc.rem(int-list.len()-i, 3) == 1 and i < int-list.len()-1 {
      string += thousandsep
    }
  }

  let printed-decimals = if digits != auto { digits } else { dec-list.len() }
  if printed-decimals > 0 {
    string += decsep
    for (i, n) in dec-list.enumerate() {
      string += str(n)
      if calc.rem(i, 3) == 2 and i != printed-decimals - 1 {
        string += thousandsep
      }
    }
    for i in range(dec-list.len(), printed-decimals) {
      string += "0"
      if calc.rem(i, 3) == 2 and i < printed-decimals - 1 {
        string += thousandsep
      }
    }
  }

  if unit != none and unit != "" and unit != [] {
    string += sym.space.nobreak + unit
  }

  string
}

// The mean of a list of numbers
#let mean(numbers) = numbers.sum() / numbers.len()

// The standard deviation of a list of numbers
#let stddev(numbers) = {
  let avg = mean(numbers)
  calc.sqrt(mean(numbers.map(n => calc.pow(n - avg, 2))))
}

// The coefficient of variation of a list of numbers
#let coef-of-var(numbers) = stddev(numbers) / mean(numbers)

#let load-benchmark(path) = {
  let data = csv(path)
  array.zip(..data).map(it => (it.at(0), it.slice(11).map(float))).to-dict()
}

#let group-benchmarks(runs, base: "base") = {
  let grouped = (:)
  for k in runs.keys() {
    let (base, ..rest) = k.split("+")
    let name = rest.join(default: "base")
    if not name in grouped { grouped.insert(name, (:)) }
    grouped.at(name).insert(base, k)
  }
  grouped
}

#let benchmark-tables(bm, title: "", base: "baseline", groups: auto, sep: ()) = {
  if groups == auto { groups = ((group: "", columns: bm.values().last().keys()),) }
  
  table(
    columns: (auto, ..(55pt, 50pt, 45pt) * bm.len()),
    align: (left, ..(right, right, right) * bm.len()),
    stroke: (x, y) => if y == 0 { (bottom: 0.5pt + black) } else { none },
    inset: (x, y) => if y == 0 { 5pt } else {
      let left = 2pt
      let right = 2pt
      if x == 0 { left = 5pt; right = 5pt }
      if calc.rem(x - 1, 3) == 0 { left = 5pt }
      if calc.rem(x - 1, 3) == 2 { right = 5pt }
      (y: 5pt, left: left, right: right)
    },
    column-gutter: (10pt, 0pt, 0pt, 10pt, 0pt, 0pt),

    table.header(title, ..bm.keys().map(it => table.cell(colspan: 3, it))),
    ..for (group, columns, ..rest) in groups {
      // (table.cell(rowspan: columns.len(), par(justify: false, group)),)
      for (i, name) in columns.enumerate() {
        let displayname = if "prefix" in rest {
          group + name.replace(rest.prefix, "")
        } else { name }
        (displayname, ..for instance in bm.values() {
          if name in instance {
            let runs = instance.at(name)
            let avg = mean(runs)
            (
              [#num(avg, digits: 2, unit: "ms")],
              [#sym.plus.minus~#num(stddev(runs), digits: 2, unit: "ms")],
              [(#text(weight: "bold")[#num(avg / mean(instance.at(base)), digits: 2)#sym.times])],
            )
          } else { ([], [], smallcaps[n/a]) }
        })
        if i in sep {
          (table.hline(stroke: (paint: luma(50%), thickness: 0.5pt, dash: "dashed")),)
        }
      }
    }
  )
}

#let benchmarks-summary(benchmarks, title: none, base, new) = {
  table(
    columns: (100pt, auto, auto),
    align: (left, ..(right,) * 6),
    stroke: (x, y) => if y == 0 { (bottom: 0.5pt + black) } else { none },
    column-gutter: 5pt,
  
    table.header(title, [x86-64], [Wasm]),
    ..for (bench-name, bench) in benchmarks {
      let bm-meta = group-benchmarks(bench)
      (bench-name, ..for (runner, key) in bm-meta.at(new) {
        let base-name = bm-meta.at(base).at(runner)
        ([#num(mean(bench.at(key)) / mean(bench.at(base-name)), digits: 2)#sym.times],)
      })
    }
  )
}

// Display the improvement of `after` over `before` in the form "2 ×"
#let improvement-times(bm, before, after, digits: 0) = num(
  digits: digits,
  unit: "times",
  mean(bm.at(before)) / mean(bm.at(after))
)

// Display the improvement of `after` over `before` in the form "100%"
#let improvement(bm, before, after) = num(
  digits: 0,
  mean(bm.at(before)) / mean(bm.at(after)) * 100 - 100
) + [%]