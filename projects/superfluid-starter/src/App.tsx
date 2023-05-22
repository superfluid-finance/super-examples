import { useAccount } from 'wagmi'

import { Account, Connect, ERC20, NetworkSwitcher, CreateFlow } from './components'
import { client } from './wagmi'

export function App() {
  console.log(client.providers)
  const clientEntries = client.providers.entries();
  const firstEntry = clientEntries.next().value;
  console.log(firstEntry[1].chains[1].rpcUrls.alchemy.http[0]);
  const clientRpc = firstEntry[1].chains[1].rpcUrls.alchemy.http[0];

  const { isConnected } = useAccount()
  return (
    <>
      <h1>wagmi + ERC20 + Vite</h1>

      <Connect />

      {isConnected && (
        <>
          <Account />
          {/* <ERC20 /> */}
          <NetworkSwitcher />
          <CreateFlow clientRpc={clientRpc}/>
          
        </>
      )}
    </>
  )
}
