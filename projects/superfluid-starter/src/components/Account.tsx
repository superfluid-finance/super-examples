import { useAccount, useEnsName } from 'wagmi'

export function Account() {
  const { address } = useAccount()
  const { data: ensName } = useEnsName({ address })

  console.log(address)

  return (
    <div>
      {ensName ?? address}
      {ensName ? ` (${address})` : null}
    </div>
  )
}
