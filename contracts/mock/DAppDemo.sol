// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.10;

import "../protocol/C3CallerDapp.sol";

contract DAppDemo is C3CallerDapp {
    event LogC3Execute(
        bytes32 uuid,
        string fromChainID,
        string sourceTx,
        bytes data
    );

    constructor(
        address _c3CallerProxy,
        uint256 _dappID
    ) C3CallerDapp(_c3CallerProxy, _dappID) {}

    function c3call(
        string calldata message,
        address receiver,
        uint256 toChainId
    ) external payable {}

    function c3Execute(
        bytes calldata data
    ) external returns (bool success, bytes memory result) {
        (
            bytes32 uuid,
            string memory fromChainID,
            string memory sourceTx
        ) = context();
        emit LogC3Execute(uuid, fromChainID, sourceTx, data);
        return (true, "");
    }

    function _c3Fallback(
        bytes4 /*selector*/,
        bytes calldata /*data*/,
        bytes calldata /*reason*/
    ) internal virtual override returns (bool) {
        return true;
    }

    function isVaildSender(address /*txSender*/) external pure returns (bool) {
        return true;
    }
}
