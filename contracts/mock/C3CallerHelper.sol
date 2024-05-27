// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../protocol/IC3Caller.sol";

contract C3CallerHelper {
    function getFallbackCallData(
        uint256 _dappID,
        bytes memory _data,
        bytes memory result
    ) public pure returns (bytes memory) {
        return
            abi.encodeWithSignature(
                "c3Fallback(uint256,bytes,bytes)",
                _dappID,
                _data,
                result
            );
    }
}
