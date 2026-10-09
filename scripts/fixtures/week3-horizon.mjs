export const EMPLOYER = 'GA63TYUUORN4FLT2QWWUVL37ERXZ5OTCEQWCIRO3PR3PYB6JUUYKGLH4'
export const WORKER = 'GB5OYIHNYJKUP6VFZHYCPLFHBF63SWIDZAPBXET4NKEFLEPWPMKIETPL'
export const OTHER_WORKER = 'GCSRX5WXQJ6PGNNSQ4VIVQAIRFL2MK4SFINU6VO55QASSRWW46HMQYNR'
export const NOW = new Date('2026-10-07T00:00:00Z')
export const IDS = [1, 2, 3, 4].map((id) => `00000000${id.toString(16).padStart(64, '0')}`)
export const FUNDING_HASH = 'a'.repeat(64)
export const CLAIM_HASH = 'b'.repeat(64)
export const CANCEL_HASH = 'c'.repeat(64)

function create(index, employee, unlock, hash = FUNDING_HASH) {
  return {
    id: String(index + 1), type: 'create_claimable_balance', source_account: EMPLOYER,
    transaction_hash: hash, transaction_successful: true, created_at: '2026-10-06T00:00:00Z',
    asset: 'native', amount: '2.0000000', claimants: [
      { destination: employee, predicate: { not: { abs_before: unlock } } },
      { destination: EMPLOYER, predicate: { abs_before: unlock } },
    ],
  }
}
export const CREATES = [
  create(0, WORKER, '2000-01-01T00:00:00Z'),
  create(1, WORKER, '2000-01-01T00:01:00Z'),
  create(2, WORKER, '2099-01-01T00:00:00Z'),
  create(3, OTHER_WORKER, '2099-01-01T00:00:00Z', 'd'.repeat(64)),
]
export const CLAIM = {
  id: '5', type: 'claim_claimable_balance', source_account: WORKER, claimant: WORKER,
  balance_id: IDS[0], transaction_hash: CLAIM_HASH, transaction_successful: true, created_at: '2026-10-06T12:00:00Z',
}
export const CANCEL = {
  id: '6', type: 'claim_claimable_balance', source_account: EMPLOYER, claimant: EMPLOYER,
  balance_id: IDS[3], transaction_hash: CANCEL_HASH, transaction_successful: true, created_at: '2026-10-06T12:01:00Z',
}
export function fixtureResponse(path) {
  const url = new URL(path, 'https://horizon-testnet.stellar.org')
  const page = (records) => ({ _embedded: { records }, _links: {} })
  if (url.pathname === `/accounts/${EMPLOYER}/operations`) return page([...CREATES, CANCEL])
  const effect = url.pathname.match(/^\/operations\/(\d+)\/effects$/)
  if (effect) return page([{ type: 'claimable_balance_created', balance_id: IDS[Number(effect[1]) - 1] }])
  const history = url.pathname.match(/^\/claimable_balances\/([a-f0-9]+)\/operations$/)
  if (history) return page([...(history[1] === IDS[0] ? [CLAIM] : history[1] === IDS[3] ? [CANCEL] : []), CREATES[IDS.indexOf(history[1])]])
  const balance = url.pathname.match(/^\/claimable_balances\/([a-f0-9]+)$/)
  if (balance) {
    const index = IDS.indexOf(balance[1])
    return [1, 2].includes(index) ? { ...CREATES[index], id: IDS[index] } : null
  }
  throw new Error(`Unexpected fixture read: ${path}`)
}
export const fixtureReader = async (path) => structuredClone(fixtureResponse(path))
