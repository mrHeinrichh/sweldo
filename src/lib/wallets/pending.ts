/** Bound connection waits and remove listeners even when an adapter never replies. */
export function pendingWallet<T>(work: Promise<T>, signal: AbortSignal): Promise<T> {
  return new Promise((resolve, reject) => {
    const abort = () => reject(signal.reason ?? new DOMException('Connection cancelled.', 'AbortError'))
    // Always observe adapter failures, even when cancellation happened already.
    work.then(resolve, reject).finally(() => signal.removeEventListener('abort', abort))
    if (signal.aborted) { abort(); return }
    signal.addEventListener('abort', abort, { once: true })
  })
}
