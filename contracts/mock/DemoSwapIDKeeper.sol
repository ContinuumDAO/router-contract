// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.10;

contract DemoSwapIDKeeper {
    address public admin;
    mapping(address => bool) public isSupportedCaller; // routers address
    address[] public supportedCallers;

    mapping(bytes32 => bool) public completedSwapin;
    mapping(bytes32 => uint256) public swapoutNonce;

    uint256 public currentSwapoutNonce;
    modifier autoIncreaseSwapoutNonce() {
        currentSwapoutNonce++;
        _;
    }

    modifier onlyAdmin() {
        require(admin == msg.sender, "DemoSwapIDKeeper: not supported caller");
        _;
    }

    modifier onlyAuth() {
        require(
            isSupportedCaller[msg.sender],
            "DemoSwapIDKeeper: not supported caller"
        );
        _;
    }

    modifier checkCompletion(bytes32 swapID) {
        require(
            !completedSwapin[swapID],
            "DemoSwapIDKeeper: swapID is completed"
        );
        _;
    }

    constructor(address _mpc) {
        admin = _mpc;
        isSupportedCaller[_mpc] = true;
    }

    function changeMPC(address newMPC) external onlyAdmin returns (bool) {
        require(newMPC != address(0), "DemoSwapIDKeeper: address(0)");
        address oldAdmin = admin;
        isSupportedCaller[oldAdmin] = false;
        admin = newMPC;
        isSupportedCaller[admin] = true;
        return true;
    }

    function getAllSupportedCallers() external view returns (address[] memory) {
        return supportedCallers;
    }

    function addSupportedCaller(address caller) external onlyAdmin {
        require(!isSupportedCaller[caller]);
        isSupportedCaller[caller] = true;
        supportedCallers.push(caller);
    }

    function removeSupportedCaller(address caller) external onlyAdmin {
        require(isSupportedCaller[caller]);
        isSupportedCaller[caller] = false;
        uint256 length = supportedCallers.length;
        for (uint256 i = 0; i < length; i++) {
            if (supportedCallers[i] == caller) {
                supportedCallers[i] = supportedCallers[length - 1];
                supportedCallers.pop();
                return;
            }
        }
    }

    function isSwapoutIDExist(bytes32 swapoutID) external view returns (bool) {
        return swapoutNonce[swapoutID] != 0;
    }

    function isSwapCompleted(bytes32 swapID) external view returns (bool) {
        return completedSwapin[swapID];
    }

    function registerSwapin(
        bytes32 swapID
    ) external onlyAuth checkCompletion(swapID) {
        completedSwapin[swapID] = true;
    }

    function registerSwapout(
        address token,
        address from,
        string calldata to,
        uint256 amount,
        string calldata toChainID,
        string calldata dapp,
        bytes calldata data
    ) external onlyAuth autoIncreaseSwapoutNonce returns (bytes32 swapID) {
        swapID = keccak256(
            abi.encode(
                address(this),
                msg.sender,
                block.chainid,
                token,
                from,
                to,
                amount,
                currentSwapoutNonce,
                toChainID,
                dapp,
                data
            )
        );
        require(!this.isSwapoutIDExist(swapID), "swapID already exist");
        swapoutNonce[swapID] = currentSwapoutNonce;
        return swapID;
    }

    function calcSwapID(
        address sender,
        address token,
        address from,
        string calldata to,
        uint256 amount,
        string calldata toChainID,
        string calldata dapp,
        bytes calldata data
    ) public view returns (bytes32) {
        uint256 nonce = currentSwapoutNonce + 1;
        return
            keccak256(
                abi.encode(
                    address(this),
                    sender,
                    block.chainid,
                    token,
                    from,
                    to,
                    amount,
                    nonce,
                    toChainID,
                    dapp,
                    data
                )
            );
    }
}
