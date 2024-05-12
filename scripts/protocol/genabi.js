const hre = require("hardhat");
const evn = require("../../output/env.json")
const { Web3 } = require('web3');
let web3 = new Web3(Web3.givenProvider);

async function main() {
    const networkName = hre.network.name
    const chainId = hre.network.config.chainId
    console.log("Deploy Network name=", networkName);
    console.log("Network chain id=", chainId);

    const [signer] = await ethers.getSigners()
    console.log("Deploying account:", signer.address);

    let govProposalData = new web3.eth.Contract(GovABI);

    let c3caller = new web3.eth.Contract(C3CallerABI);
    let calldata = c3caller.methods.addOperator(signer.address).encodeABI()

    console.log(govProposalData.methods.genProposalData(421614, evn["ARB_TEST"].C3CallerProxy, calldata).encodeABI().substring(10))

}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
const GovABI = [
    {
        "inputs": [
            {
                "internalType": "uint256",
                "name": "chainId",
                "type": "uint256"
            },
            {
                "internalType": "string",
                "name": "target",
                "type": "string"
            },
            {
                "internalType": "bytes",
                "name": "data",
                "type": "bytes"
            }
        ],
        "name": "genProposalData",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
]

const C3CallerABI = [
    {
        "inputs": [
            {
                "internalType": "address",
                "name": "_swapIDKeeper",
                "type": "address"
            }
        ],
        "stateMutability": "nonpayable",
        "type": "constructor"
    },
    {
        "anonymous": false,
        "inputs": [
            {
                "indexed": true,
                "internalType": "address",
                "name": "oldGov",
                "type": "address"
            },
            {
                "indexed": true,
                "internalType": "address",
                "name": "newGov",
                "type": "address"
            },
            {
                "indexed": false,
                "internalType": "uint256",
                "name": "timestamp",
                "type": "uint256"
            }
        ],
        "name": "ApplyGov",
        "type": "event"
    },
    {
        "anonymous": false,
        "inputs": [
            {
                "indexed": true,
                "internalType": "address",
                "name": "oldGov",
                "type": "address"
            },
            {
                "indexed": true,
                "internalType": "address",
                "name": "newGov",
                "type": "address"
            },
            {
                "indexed": false,
                "internalType": "uint256",
                "name": "timestamp",
                "type": "uint256"
            }
        ],
        "name": "ChangeGov",
        "type": "event"
    },
    {
        "anonymous": false,
        "inputs": [
            {
                "indexed": false,
                "internalType": "uint8",
                "name": "version",
                "type": "uint8"
            }
        ],
        "name": "Initialized",
        "type": "event"
    },
    {
        "anonymous": false,
        "inputs": [
            {
                "indexed": true,
                "internalType": "uint256",
                "name": "dappID",
                "type": "uint256"
            },
            {
                "indexed": true,
                "internalType": "bytes32",
                "name": "uuid",
                "type": "bytes32"
            },
            {
                "indexed": false,
                "internalType": "address",
                "name": "caller",
                "type": "address"
            },
            {
                "indexed": false,
                "internalType": "string",
                "name": "toChainID",
                "type": "string"
            },
            {
                "indexed": false,
                "internalType": "string",
                "name": "to",
                "type": "string"
            },
            {
                "indexed": false,
                "internalType": "bytes",
                "name": "data",
                "type": "bytes"
            }
        ],
        "name": "LogC3Call",
        "type": "event"
    },
    {
        "anonymous": false,
        "inputs": [
            {
                "indexed": true,
                "internalType": "uint256",
                "name": "dappID",
                "type": "uint256"
            },
            {
                "indexed": true,
                "internalType": "address",
                "name": "to",
                "type": "address"
            },
            {
                "indexed": true,
                "internalType": "bytes32",
                "name": "uuid",
                "type": "bytes32"
            },
            {
                "indexed": false,
                "internalType": "string",
                "name": "fromChainID",
                "type": "string"
            },
            {
                "indexed": false,
                "internalType": "string",
                "name": "sourceTx",
                "type": "string"
            },
            {
                "indexed": false,
                "internalType": "bytes",
                "name": "data",
                "type": "bytes"
            },
            {
                "indexed": false,
                "internalType": "bool",
                "name": "success",
                "type": "bool"
            },
            {
                "indexed": false,
                "internalType": "bytes",
                "name": "reasons",
                "type": "bytes"
            }
        ],
        "name": "LogExecCall",
        "type": "event"
    },
    {
        "anonymous": false,
        "inputs": [
            {
                "indexed": true,
                "internalType": "uint256",
                "name": "dappID",
                "type": "uint256"
            },
            {
                "indexed": true,
                "internalType": "address",
                "name": "to",
                "type": "address"
            },
            {
                "indexed": true,
                "internalType": "bool",
                "name": "success",
                "type": "bool"
            },
            {
                "indexed": false,
                "internalType": "bytes32",
                "name": "uuid",
                "type": "bytes32"
            },
            {
                "indexed": false,
                "internalType": "string",
                "name": "fromChainID",
                "type": "string"
            },
            {
                "indexed": false,
                "internalType": "string",
                "name": "sourceTx",
                "type": "string"
            },
            {
                "indexed": false,
                "internalType": "bytes",
                "name": "fallbackReason",
                "type": "bytes"
            },
            {
                "indexed": false,
                "internalType": "bytes",
                "name": "data",
                "type": "bytes"
            },
            {
                "indexed": false,
                "internalType": "bytes",
                "name": "reasons",
                "type": "bytes"
            }
        ],
        "name": "LogExecFallback",
        "type": "event"
    },
    {
        "anonymous": false,
        "inputs": [
            {
                "indexed": true,
                "internalType": "uint256",
                "name": "dappID",
                "type": "uint256"
            },
            {
                "indexed": true,
                "internalType": "bytes32",
                "name": "uuid",
                "type": "bytes32"
            },
            {
                "indexed": false,
                "internalType": "string",
                "name": "to",
                "type": "string"
            },
            {
                "indexed": false,
                "internalType": "bytes",
                "name": "data",
                "type": "bytes"
            }
        ],
        "name": "LogFallbackCall",
        "type": "event"
    },
    {
        "anonymous": false,
        "inputs": [
            {
                "indexed": false,
                "internalType": "address",
                "name": "account",
                "type": "address"
            }
        ],
        "name": "Paused",
        "type": "event"
    },
    {
        "anonymous": false,
        "inputs": [
            {
                "indexed": false,
                "internalType": "address",
                "name": "account",
                "type": "address"
            }
        ],
        "name": "Unpaused",
        "type": "event"
    },
    {
        "inputs": [
            {
                "internalType": "address",
                "name": "_op",
                "type": "address"
            }
        ],
        "name": "addOperator",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "applyGov",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [
            {
                "internalType": "uint256",
                "name": "_dappID",
                "type": "uint256"
            },
            {
                "components": [
                    {
                        "internalType": "bytes32",
                        "name": "uuid",
                        "type": "bytes32"
                    },
                    {
                        "internalType": "address",
                        "name": "to",
                        "type": "address"
                    },
                    {
                        "internalType": "string",
                        "name": "fromChainID",
                        "type": "string"
                    },
                    {
                        "internalType": "string",
                        "name": "sourceTx",
                        "type": "string"
                    },
                    {
                        "internalType": "string",
                        "name": "fallbackTo",
                        "type": "string"
                    },
                    {
                        "internalType": "bytes",
                        "name": "data",
                        "type": "bytes"
                    },
                    {
                        "internalType": "bytes",
                        "name": "reason",
                        "type": "bytes"
                    }
                ],
                "internalType": "struct C3CallerStructLib.C3EvmFallbackMessage",
                "name": "_message",
                "type": "tuple"
            }
        ],
        "name": "c3Fallback",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [
            {
                "internalType": "uint256",
                "name": "_dappID",
                "type": "uint256"
            },
            {
                "internalType": "address",
                "name": "_caller",
                "type": "address"
            },
            {
                "internalType": "string[]",
                "name": "_to",
                "type": "string[]"
            },
            {
                "internalType": "string[]",
                "name": "_toChainIDs",
                "type": "string[]"
            },
            {
                "internalType": "bytes",
                "name": "_data",
                "type": "bytes"
            }
        ],
        "name": "c3broadcast",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [
            {
                "internalType": "uint256",
                "name": "_dappID",
                "type": "uint256"
            },
            {
                "internalType": "address",
                "name": "_caller",
                "type": "address"
            },
            {
                "internalType": "string",
                "name": "_to",
                "type": "string"
            },
            {
                "internalType": "string",
                "name": "_toChainID",
                "type": "string"
            },
            {
                "internalType": "bytes",
                "name": "_data",
                "type": "bytes"
            }
        ],
        "name": "c3call",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [
            {
                "internalType": "address",
                "name": "_gov",
                "type": "address"
            }
        ],
        "name": "changeGov",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "context",
        "outputs": [
            {
                "internalType": "bytes32",
                "name": "swapID",
                "type": "bytes32"
            },
            {
                "internalType": "string",
                "name": "fromChainID",
                "type": "string"
            },
            {
                "internalType": "string",
                "name": "sourceTx",
                "type": "string"
            },
            {
                "internalType": "bytes",
                "name": "reason",
                "type": "bytes"
            }
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [
            {
                "internalType": "uint256",
                "name": "_dappID",
                "type": "uint256"
            },
            {
                "components": [
                    {
                        "internalType": "bytes32",
                        "name": "uuid",
                        "type": "bytes32"
                    },
                    {
                        "internalType": "address",
                        "name": "to",
                        "type": "address"
                    },
                    {
                        "internalType": "string",
                        "name": "fromChainID",
                        "type": "string"
                    },
                    {
                        "internalType": "string",
                        "name": "sourceTx",
                        "type": "string"
                    },
                    {
                        "internalType": "string",
                        "name": "fallbackTo",
                        "type": "string"
                    },
                    {
                        "internalType": "bytes",
                        "name": "data",
                        "type": "bytes"
                    }
                ],
                "internalType": "struct C3CallerStructLib.C3EvmMessage",
                "name": "_message",
                "type": "tuple"
            }
        ],
        "name": "execute",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "getAllOperators",
        "outputs": [
            {
                "internalType": "address[]",
                "name": "",
                "type": "address[]"
            }
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "gov",
        "outputs": [
            {
                "internalType": "address",
                "name": "",
                "type": "address"
            }
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [
            {
                "internalType": "address",
                "name": "",
                "type": "address"
            }
        ],
        "name": "isOperator",
        "outputs": [
            {
                "internalType": "bool",
                "name": "",
                "type": "bool"
            }
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [
            {
                "internalType": "uint256",
                "name": "",
                "type": "uint256"
            }
        ],
        "name": "operators",
        "outputs": [
            {
                "internalType": "address",
                "name": "",
                "type": "address"
            }
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "pause",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "paused",
        "outputs": [
            {
                "internalType": "bool",
                "name": "",
                "type": "bool"
            }
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "pendingGov",
        "outputs": [
            {
                "internalType": "address",
                "name": "",
                "type": "address"
            }
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [
            {
                "internalType": "address",
                "name": "_op",
                "type": "address"
            }
        ],
        "name": "revokeOperator",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "unpause",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "uuidKeeper",
        "outputs": [
            {
                "internalType": "address",
                "name": "",
                "type": "address"
            }
        ],
        "stateMutability": "view",
        "type": "function"
    }
]