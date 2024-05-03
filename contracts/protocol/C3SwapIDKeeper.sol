// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.10;

import "./ISwapIDKeeper.sol";

contract C3SwapIDKeeper is ISwapIDKeeper {
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
        require(admin == msg.sender, "C3SwapIDKeeper: not supported caller");
        _;
    }

    modifier onlyAuth() {
        require(
            isSupportedCaller[msg.sender],
            "C3SwapIDKeeper: not supported caller"
        );
        _;
    }

    modifier checkCompletion(bytes32 uuid) {
        require(!completedSwapin[uuid], "C3SwapIDKeeper: uuid is completed");
        _;
    }

    constructor(address _mpc) {
        admin = _mpc;
        isSupportedCaller[_mpc] = true;
    }

    function changeMPC(address newMPC) external onlyAdmin returns (bool) {
        require(newMPC != address(0), "C3SwapIDKeeper: address(0)");
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

    function isSwapoutIDExist(bytes32 uuid) external view returns (bool) {
        return swapoutNonce[uuid] != 0;
    }

    function isSwapCompleted(bytes32 uuid) external view returns (bool) {
        return completedSwapin[uuid];
    }

    function revokeSwapin(bytes32 uuid) external onlyAdmin {
        completedSwapin[uuid] = false;
    }

    function registerSwapin(
        bytes32 uuid
    ) external onlyAuth checkCompletion(uuid) {
        completedSwapin[uuid] = true;
    }

    function registerSwapout(
        uint256 dappID,
        address token,
        address from,
        string calldata to,
        uint256 amount,
        string calldata toChainID,
        bytes calldata data
    ) external onlyAuth autoIncreaseSwapoutNonce returns (bytes32 uuid) {
        uuid = keccak256(
            abi.encode(
                address(this),
                msg.sender,
                block.chainid,
                dappID,
                token,
                from,
                to,
                amount,
                currentSwapoutNonce,
                toChainID,
                data
            )
        );
        require(!this.isSwapoutIDExist(uuid), "uuid already exist");
        swapoutNonce[uuid] = currentSwapoutNonce;
        return uuid;
    }

    function genUUID(
        uint256 dappID,
        string calldata to,
        string calldata toChainID,
        bytes calldata data
    ) external onlyAuth autoIncreaseSwapoutNonce returns (bytes32 uuid) {
        uuid = keccak256(
            abi.encode(
                address(this),
                msg.sender,
                block.chainid,
                dappID,
                to,
                toChainID,
                currentSwapoutNonce,
                data
            )
        );
        require(!this.isSwapoutIDExist(uuid), "uuid already exist");
        swapoutNonce[uuid] = currentSwapoutNonce;
        return uuid;
    }

    function calcCallerUUID(
        address from,
        uint256 dappID,
        string calldata to,
        string calldata toChainID,
        bytes calldata data
    ) public view returns (bytes32) {
        uint256 nonce = currentSwapoutNonce + 1;
        return
            keccak256(
                abi.encode(
                    address(this),
                    from,
                    block.chainid,
                    dappID,
                    to,
                    toChainID,
                    nonce,
                    data
                )
            );
    }

    // TODO test code
    function calcCallerEncode(
        address from,
        uint256 dappID,
        string calldata to,
        string calldata toChainID,
        bytes calldata data
    ) public view returns (bytes memory) {
        uint256 nonce = currentSwapoutNonce + 1;
        return
            abi.encode(
                address(this),
                from,
                block.chainid,
                dappID,
                to,
                toChainID,
                nonce,
                data
            );
    }
}
