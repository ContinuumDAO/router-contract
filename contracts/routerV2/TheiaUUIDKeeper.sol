// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.10;

import "./ITheiaUUIDKeeper.sol";
import "./GovernDapp.sol";

contract TheiaUUIDKeeper is ITheiaUUIDKeeper, GovernDapp {
    mapping(address => bool) public isSupportedCaller; // routers address
    address[] public supportedCallers;

    mapping(bytes32 => bool) public completedUUID;
    mapping(bytes32 => uint256) public uuidNonce;

    uint256 public currentNonce;
    modifier autoIncreaseSwapoutNonce() {
        currentNonce++;
        _;
    }

    modifier onlyRouter() {
        require(
            isSupportedCaller[msg.sender],
            "TheiaUUIDKeeper: not supported caller"
        );
        _;
    }

    modifier checkCompletion(bytes32 uuid) {
        require(!completedUUID[uuid], "TheiaUUIDKeeper: uuid is completed");
        _;
    }

    constructor(
        address _gov,
        address _c3callerProxy,
        address _txSender,
        uint256 _dappID
    ) GovernDapp(_gov, _c3callerProxy, _txSender, _dappID) {}

    function getAllSupportedCallers() external view returns (address[] memory) {
        return supportedCallers;
    }

    function addSupportedCaller(
        address caller
    ) external onlyGov returns (bool) {
        require(!isSupportedCaller[caller]);
        isSupportedCaller[caller] = true;
        supportedCallers.push(caller);
        return true;
    }

    function removeSupportedCaller(
        address caller
    ) external onlyGov returns (bool) {
        require(isSupportedCaller[caller]);
        isSupportedCaller[caller] = false;
        uint256 length = supportedCallers.length;
        for (uint256 i = 0; i < length; i++) {
            if (supportedCallers[i] == caller) {
                supportedCallers[i] = supportedCallers[length - 1];
                supportedCallers.pop();
                return true;
            }
        }
        return true;
    }

    function isExist(bytes32 swapoutID) external view returns (bool) {
        return uuidNonce[swapoutID] != 0;
    }

    function isCompleted(bytes32 uuid) external view returns (bool) {
        return completedUUID[uuid];
    }

    function registerUUID(
        bytes32 uuid
    ) external onlyRouter checkCompletion(uuid) {
        completedUUID[uuid] = true;
    }

    function genUUIDEvm(
        EvmData memory data
    ) external onlyRouter autoIncreaseSwapoutNonce returns (bytes32 uuid) {
        uuid = keccak256(
            abi.encode(
                address(this),
                msg.sender,
                block.chainid,
                data.token,
                data.from,
                data.receiver,
                data.amount,
                currentNonce,
                data.toChainID
            )
        );
        require(!this.isExist(uuid), "TheiaUUIDKeeper: uuid already exist");
        uuidNonce[uuid] = currentNonce;
        return uuid;
    }

    function genUUIDNonEvm(
        NonEvmData memory data
    ) external onlyRouter autoIncreaseSwapoutNonce returns (bytes32 uuid) {
        uuid = keccak256(
            abi.encode(
                address(this),
                msg.sender,
                block.chainid,
                data.token,
                data.from,
                data.receiver,
                data.amount,
                currentNonce,
                data.toChainID,
                data.callData
            )
        );
        require(!this.isExist(uuid), "TheiaUUIDKeeper: uuid already exist");
        uuidNonce[uuid] = currentNonce;
        return uuid;
    }

    function _c3Fallback(
        bytes4 /*selector*/,
        bytes calldata /*data*/,
        bytes calldata /*reason*/
    ) internal virtual override returns (bool) {
        return true;
    }
}
