// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import "./TheiaERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { UD60x18, ud } from "@prb/math/src/UD60x18.sol";

interface CallProxy{
    function c3Caller(
        address _to,
        bytes calldata _data,
        uint256 _toChainID,
        uint256 _flags,
        bytes calldata _extdata
    ) external payable;

    function context() external view returns (address from, uint256 fromChainID, uint256 nonce);
    
    function executor() external view returns (address executor);
}

contract THEIA is TheiaERC20, AccessControl {

    using SafeERC20 for IERC20;

    address public c3CallContract;

    bytes32 public constant GOV = keccak256("GOV");

    uint256 constant public INITIAL_EMISSION_PER_YEAR = 10000000;  // Initial emission rate 10 million/year
    uint256 public emission_rate;
    uint256 constant internal SECS_PER_YEAR = 3600*(365*24 + 6);
    
    uint256 public offsetYears = 1;
    uint256 public initTime = offsetYears*SECS_PER_YEAR;

    uint256 public fac = 10000001;
    
    uint256 lastClaim;

    address admin;
    address gov;

    uint256 startTime;

    constructor(
        address _defaultAdmin, 
        address _defaultGov, 
        address _c3CallContract
        ) TheiaERC20("Theia", "THEIA", 18, address(0x00), address(0x00)) {
        admin = _defaultAdmin;
        gov = _defaultGov;
        c3CallContract = _c3CallContract;

        startTime = block.timestamp;
        lastClaim = startTime;
        

        _setRoleAdmin(DEFAULT_ADMIN_ROLE, GOV);
        _setRoleAdmin(GOV, GOV);
        _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
        _grantRole(GOV, _defaultGov);

        _mint(admin, 10000000*10**decimals);  // initial mint 10 million.
    }

    event changeC3CallerContract(address c3CallContract);

    modifier onlyAdmin() {
        require(isAdmin(msg.sender), 'Restricted to admins');
        _;
    }

    modifier onlyGov() {
        require(isGov(msg.sender), 'Restricted to the govenor');
        _;
    }

    function isAdmin(address account) public virtual view returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, account);
    }

    function isGov(address account) public virtual view returns (bool) {
        return hasRole(GOV, account);
    }

    function setGov(address _oldGov, address _newGov) public {
        grantRole(GOV, _newGov);
        revokeRole(GOV, _oldGov);
    }

    // function setAdmin(address account) public onlyGov {
    //     grantRole(DEFAULT_ADMIN_ROLE, account);
    // }

    function unsetAdmin() public onlyAdmin {
        revokeRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function tokenEmission() public view returns(uint256) {

        uint256 emission = tokenEmissionAt(block.timestamp);
        return(emission);
    }

    function tokenEmissionAt(uint256 time) public view returns(uint256) {

        uint256 emission = fac*10**decimals/(initTime + time);

        return(emission);
    }

    function tokenAlloc() external onlyGov returns(uint256) {

        UD60x18 timeNow = ud(1e18*(initTime + block.timestamp));
        UD60x18 lastTime = ud(1e18*(initTime + lastClaim));
        

        UD60x18 p2 = timeNow.ln();
        UD60x18 p1 = lastTime.ln();
        UD60x18 factor = ud(fac*1e18);
        UD60x18 alloc = factor.mul(p2.sub(p1));

        uint256 allocation = alloc.intoUint256();
        
        _mint(msg.sender, allocation);

        lastClaim = block.timestamp;

        return(allocation);
    }

}