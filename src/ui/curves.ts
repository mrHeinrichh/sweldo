// Flutter's curves, solved the same way (`Cubic.transform`), so time-driven
// animations land on the same frames as the Flutter app.

export type Curve = (t: number) => number

export function cubic(a: number, b: number, c: number, d: number): Curve {
  const evaluate = (p1: number, p2: number, m: number) => 3 * p1 * (1 - m) * (1 - m) * m + 3 * p2 * (1 - m) * m * m + m * m * m
  return (t) => {
    if (t <= 0) return 0
    if (t >= 1) return 1
    let start = 0
    let end = 1
    for (;;) {
      const midpoint = (start + end) / 2
      const estimate = evaluate(a, c, midpoint)
      if (Math.abs(t - estimate) < 0.001) return evaluate(b, d, midpoint)
      if (estimate < t) start = midpoint
      else end = midpoint
    }
  }
}

export const easeOutCubic = cubic(0.215, 0.61, 0.355, 1)
export const easeInOutCubic = cubic(0.645, 0.045, 0.355, 1)
export const easeOutBack = cubic(0.175, 0.885, 0.32, 1.275)
export const easeOut = cubic(0.25, 0.1, 0.25, 1)
export const stampCurve = cubic(0.2, 1.6, 0.4, 1)

export const clamp = (value: number, min: number, max: number) => Math.min(max, Math.max(min, value))
export const lerp = (a: number, b: number, t: number) => a + (b - a) * t
