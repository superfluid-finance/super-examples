import { useState } from 'react'
import {ethers} from 'ethers';
import { useAccount, useNetwork, useWaitForTransaction } from 'wagmi'
import sfMeta from '@superfluid-finance/metadata'
import { CFAv1Forwarder__factory } from '@superfluid-finance/ethereum-contracts/build/typechain'
import { useContractWrite, usePrepareContractWrite } from 'wagmi'
import { client } from '../wagmi';

//specific to mumbai, but would be quite easy to make gen purpose
export function CreateFlow( clientRpc: any ) {
    const { address } = useAccount()
    const [flowRate, setFlowRate] = useState<ethers.BigNumber>(ethers.BigNumber.from(0))
    const [receiver, setReceiver] = useState<`0x${string}`>("0x0000000000000000000000000000000000000000")
    const [token, setToken] = useState<`0x${string}`>("0x0000000000000000000000000000000000000000")
    const mumbai = sfMeta.getNetworkByName('polygon-mumbai')
    const mumbaiAddress: `0x${string}` = mumbai?.contractsV1.cfaV1Forwarder as `0x${string}`

    const { config } = usePrepareContractWrite({
        address: mumbaiAddress,
        abi: CFAv1Forwarder__factory.abi,
        functionName: 'createFlow',
        args: [token, address, receiver, flowRate, "0x"],
    })
    const { data, isLoading, isSuccess, write } = useContractWrite(config)
    
    let mumbaiNetworkObject = {};
    let networkObjects = [];
    
    async function handleCreateFlow(e: any) {
        e.preventDefault()
        if (config) {
            const tx = write?.()
            console.log(tx)
        }        
    }

    return (
        <div>
            <h2>Create Flow</h2>
            <form>
                <label>
                    <input type="text" placeholder="enter the address of the token you'd like to send" value={token} onChange={(e) => setToken(e.target.value)} />
                </label>
                <p>
                <label>
                    <input type="text" placeholder="enter the address of your receiver here" value={receiver} onChange={(e) => setReceiver(e.target.value)} />
                </label>
                </p>
                <p>
                <label>
                    <input type="text" placeholder="enter a flowRate here in wei/second" value={flowRate} onChange={(e) => setFlowRate(e.target.value)} />
                </label>
                </p>
                <button type="submit" onClick={handleCreateFlow}>Create Flow</button>
            </form>
        </div>
    )
}