/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import { Contract, Signer, utils } from "ethers"
import type { Provider } from "@ethersproject/providers"
import type {
    AutomateReady,
    AutomateReadyInterface
} from "../../../src/gelato/AutomateReady"

const _abi = [
    {
        inputs: [],
        name: "automate",
        outputs: [
            {
                internalType: "contract IAutomate",
                name: "",
                type: "address"
            }
        ],
        stateMutability: "view",
        type: "function"
    },
    {
        inputs: [],
        name: "dedicatedMsgSender",
        outputs: [
            {
                internalType: "address",
                name: "",
                type: "address"
            }
        ],
        stateMutability: "view",
        type: "function"
    }
] as const

export class AutomateReady__factory {
    static readonly abi = _abi
    static createInterface(): AutomateReadyInterface {
        return new utils.Interface(_abi) as AutomateReadyInterface
    }
    static connect(
        address: string,
        signerOrProvider: Signer | Provider
    ): AutomateReady {
        return new Contract(address, _abi, signerOrProvider) as AutomateReady
    }
}
