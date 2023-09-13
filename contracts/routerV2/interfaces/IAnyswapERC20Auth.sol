// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

interface IAnyswapERC20Auth {
    function changeVault(address newVault) external returns (bool);
}
