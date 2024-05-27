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

    calldata = "0x6e2fa4590000000000000000000000008FaBad0a0cECA3CCd6EBb0D3662d1BCC121a5804"

    console.log(govProposalData.methods.genProposalData(chainId, evn[networkName.toUpperCase()].TheiaRouter, calldata).encodeABI().substring(10))


    // let c3DappManager = new web3.eth.Contract(C3DappManagerABI);
    // calldata = c3DappManager.methods.setFeeCurrencies(["0x2A2a5e1e2475Bf35D8F3f85D8C736f376BDb1C02"], ["10000000000000000"]).encodeABI()

    // console.log(govProposalData.methods.genProposalData(chainId, evn[networkName.toUpperCase()].C3DappManager, calldata).encodeABI().substring(10))

    console.log(web3.utils.randomHex(32))
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

const C3DappManagerABI = [
    {
        "inputs": [],
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
                "indexed": true,
                "internalType": "uint256",
                "name": "dappID",
                "type": "uint256"
            },
            {
                "indexed": true,
                "internalType": "address",
                "name": "token",
                "type": "address"
            },
            {
                "indexed": false,
                "internalType": "uint256",
                "name": "bill",
                "type": "uint256"
            },
            {
                "indexed": false,
                "internalType": "uint256",
                "name": "amount",
                "type": "uint256"
            },
            {
                "indexed": false,
                "internalType": "uint256",
                "name": "left",
                "type": "uint256"
            }
        ],
        "name": "Charging",
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
                "name": "token",
                "type": "address"
            },
            {
                "indexed": false,
                "internalType": "uint256",
                "name": "amount",
                "type": "uint256"
            },
            {
                "indexed": false,
                "internalType": "uint256",
                "name": "left",
                "type": "uint256"
            }
        ],
        "name": "Deposit",
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
                "internalType": "uint256",
                "name": "dappID",
                "type": "uint256"
            },
            {
                "indexed": false,
                "internalType": "bool",
                "name": "flag",
                "type": "bool"
            }
        ],
        "name": "SetBlacklists",
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
                "indexed": false,
                "internalType": "string[]",
                "name": "addresses",
                "type": "string[]"
            }
        ],
        "name": "SetDAppAddr",
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
                "name": "appAdmin",
                "type": "address"
            },
            {
                "indexed": true,
                "internalType": "address",
                "name": "feeToken",
                "type": "address"
            },
            {
                "indexed": false,
                "internalType": "string",
                "name": "appDomain",
                "type": "string"
            },
            {
                "indexed": false,
                "internalType": "string",
                "name": "email",
                "type": "string"
            }
        ],
        "name": "SetDAppConfig",
        "type": "event"
    },
    {
        "anonymous": false,
        "inputs": [
            {
                "indexed": true,
                "internalType": "address",
                "name": "token",
                "type": "address"
            },
            {
                "indexed": false,
                "internalType": "string",
                "name": "chain",
                "type": "string"
            },
            {
                "indexed": false,
                "internalType": "uint256",
                "name": "callPerByteFee",
                "type": "uint256"
            }
        ],
        "name": "SetFeeConfig",
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
                "name": "token",
                "type": "address"
            },
            {
                "indexed": false,
                "internalType": "uint256",
                "name": "amount",
                "type": "uint256"
            },
            {
                "indexed": false,
                "internalType": "uint256",
                "name": "left",
                "type": "uint256"
            }
        ],
        "name": "Withdraw",
        "type": "event"
    },
    {
        "inputs": [
            {
                "internalType": "uint256",
                "name": "_dappID",
                "type": "uint256"
            },
            {
                "internalType": "string[]",
                "name": "_whitelist",
                "type": "string[]"
            }
        ],
        "name": "addDappAddr",
        "outputs": [],
        "stateMutability": "nonpayable",
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
        "inputs": [
            {
                "internalType": "uint256[]",
                "name": "_dappIDs",
                "type": "uint256[]"
            },
            {
                "internalType": "address[]",
                "name": "_tokens",
                "type": "address[]"
            },
            {
                "internalType": "uint256[]",
                "name": "_amounts",
                "type": "uint256[]"
            }
        ],
        "name": "charging",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "dappID",
        "outputs": [
            {
                "internalType": "uint256",
                "name": "",
                "type": "uint256"
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
            },
            {
                "internalType": "address",
                "name": "",
                "type": "address"
            }
        ],
        "name": "dappStakePool",
        "outputs": [
            {
                "internalType": "uint256",
                "name": "",
                "type": "uint256"
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
                "internalType": "string[]",
                "name": "_whitelist",
                "type": "string[]"
            }
        ],
        "name": "delWhitelists",
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
                "name": "_token",
                "type": "address"
            },
            {
                "internalType": "uint256",
                "name": "_amount",
                "type": "uint256"
            }
        ],
        "name": "deposit",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [
            {
                "internalType": "address",
                "name": "_token",
                "type": "address"
            }
        ],
        "name": "disableFeeCurrency",
        "outputs": [],
        "stateMutability": "nonpayable",
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
        "name": "feeCurrencies",
        "outputs": [
            {
                "internalType": "uint256",
                "name": "",
                "type": "uint256"
            }
        ],
        "stateMutability": "view",
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
                "name": "_feeToken",
                "type": "address"
            },
            {
                "internalType": "string",
                "name": "_appDomain",
                "type": "string"
            },
            {
                "internalType": "string",
                "name": "_email",
                "type": "string"
            },
            {
                "internalType": "string[]",
                "name": "_whitelist",
                "type": "string[]"
            }
        ],
        "name": "initDappConfig",
        "outputs": [],
        "stateMutability": "nonpayable",
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
                "internalType": "uint256",
                "name": "_dappID",
                "type": "uint256"
            },
            {
                "internalType": "address",
                "name": "_newAdmin",
                "type": "address"
            }
        ],
        "name": "resetAdmin",
        "outputs": [],
        "stateMutability": "nonpayable",
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
        "inputs": [
            {
                "internalType": "uint256",
                "name": "_dappID",
                "type": "uint256"
            },
            {
                "internalType": "bool",
                "name": "_flag",
                "type": "bool"
            }
        ],
        "name": "setBlacklists",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [
            {
                "internalType": "address[]",
                "name": "_tokens",
                "type": "address[]"
            },
            {
                "internalType": "uint256[]",
                "name": "_callfee",
                "type": "uint256[]"
            }
        ],
        "name": "setFeeCurrencies",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [
            {
                "internalType": "address",
                "name": "_token",
                "type": "address"
            },
            {
                "internalType": "string",
                "name": "_chain",
                "type": "string"
            },
            {
                "internalType": "uint256",
                "name": "_callfee",
                "type": "uint256"
            }
        ],
        "name": "setSpeFeeConfigByChain",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [
            {
                "internalType": "string",
                "name": "",
                "type": "string"
            },
            {
                "internalType": "address",
                "name": "",
                "type": "address"
            }
        ],
        "name": "speChainFees",
        "outputs": [
            {
                "internalType": "uint256",
                "name": "",
                "type": "uint256"
            }
        ],
        "stateMutability": "view",
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
        "inputs": [
            {
                "internalType": "uint256",
                "name": "_dappID",
                "type": "uint256"
            },
            {
                "internalType": "address",
                "name": "_feeToken",
                "type": "address"
            },
            {
                "internalType": "string",
                "name": "_appID",
                "type": "string"
            },
            {
                "internalType": "string",
                "name": "_email",
                "type": "string"
            }
        ],
        "name": "updateDAppConfig",
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
                "name": "_feeToken",
                "type": "address"
            },
            {
                "internalType": "uint256",
                "name": "_discount",
                "type": "uint256"
            }
        ],
        "name": "updateDappByGov",
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
                "name": "_token",
                "type": "address"
            },
            {
                "internalType": "uint256",
                "name": "_amount",
                "type": "uint256"
            }
        ],
        "name": "withdraw",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [
            {
                "internalType": "address[]",
                "name": "_tokens",
                "type": "address[]"
            }
        ],
        "name": "withdrawFees",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [
            {
                "internalType": "address[]",
                "name": "_tokens",
                "type": "address[]"
            },
            {
                "internalType": "address",
                "name": "to",
                "type": "address"
            }
        ],
        "name": "withdrawFeesTo",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    }
]

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