// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IC3DApp {
    function c3Execute(
        bytes calldata _data
    ) external returns (bool success, bytes memory result);
}
