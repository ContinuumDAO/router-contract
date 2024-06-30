// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../protocol/C3CallerDapp.sol";
// import "https://github.com/ContinuumDAO/router-contract/blob/main/contracts/protocol/C3CallerDapp.sol";

contract CToken is ERC20, C3CallerDapp {
    using Strings for *;

    uint8 private _decimals;

    bytes4 public FuncCrossIn = bytes4(keccak256("crossIn(address,uint256)"));

    constructor(
        string memory name_,
        string memory symbol_,
        address c3callerProxy_,
        uint256 dappID_,
        uint8 decimals_
    ) ERC20(name_, symbol_) C3CallerDapp(c3callerProxy_, dappID_) {
        _decimals = decimals_;
        _mint(msg.sender, 100000000 * 10 ** _decimals);
    }

    function claim(uint256 amount) public {
        _mint(msg.sender, amount);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function crossTo(
        uint256 chainID_,
        address ctokenAddr_,
        uint256 amount_
    ) public {
        _burn(msg.sender, amount_);

        c3call(
            ctokenAddr_.toHexString(),
            chainID_.toString(),
            abi.encodeWithSignature(
                "crossIn(address,uint256)",
                msg.sender,
                amount_
            )
        );
    }

    function crossIn(
        address to_,
        uint256 amount_
    ) external onlyCaller returns (bool) {
        _mint(to_, amount_);
        return true;
    }

    function _c3Fallback(
        bytes4 selector,
        bytes calldata data_,
        bytes calldata /*reason_*/
    ) internal override returns (bool) {
        (address to, uint256 amount) = abi.decode(data_, (address, uint256));
        require(to != address(0), "empty to");
        require(amount > 0, "empty amount");
        if (selector == FuncCrossIn) {
            _mint(to, amount);
            return true;
        } else {
            return false;
        }
    }

    function isVaildSender(address /*txSender*/) external pure returns (bool) {
        return true;
    }
}
