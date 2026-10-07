/** The nearest ancestor that scrolls vertically (the shell's page area). */
function scrollParent(element: Element): HTMLElement {
  let node = element.parentElement
  while (node) {
    const overflow = getComputedStyle(node).overflowY
    if ((overflow === 'auto' || overflow === 'scroll') && node.scrollHeight > node.clientHeight) return node
    node = node.parentElement
  }
  return document.scrollingElement as HTMLElement
}

/**
 * Flutter's Scrollable.ensureVisible: `alignment` 0 puts the element's top at
 * the top of the viewport, 1 puts its bottom at the bottom.
 */
export function ensureVisible(element: Element, alignment: number, smooth = true) {
  const scroller = scrollParent(element)
  const rect = element.getBoundingClientRect()
  const viewport = scroller === document.scrollingElement
    ? { top: 0, height: window.innerHeight }
    : { top: scroller.getBoundingClientRect().top, height: scroller.clientHeight }
  const target = scroller.scrollTop + (rect.top - viewport.top) - (viewport.height - rect.height) * alignment
  const max = scroller.scrollHeight - scroller.clientHeight
  scroller.scrollTo({ top: Math.max(0, Math.min(max, target)), behavior: smooth ? 'smooth' : 'auto' })
}
