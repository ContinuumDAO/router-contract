// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./IC3Caller.sol";

contract C3CallerProxy is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    IC3CallerProxy
{
    address public mpc;
    address public pendingMPC;

    address public c3caller;

    mapping(address => bool) public isOperator;
    address[] public operators;

    modifier onlyAuth() {
        require(isOperator[msg.sender], "C3CallerProxy: AUTH FORBIDDEN");
        _;
    }

    // constructor(address _mpc, address _c3caller) {
    //     require(_mpc != address(0));
    //     mpc = _mpc;
    //     _addOperator(_mpc);
    //     c3caller = _c3caller;
    // }

    function initialize(address _mpc, address _c3caller) public initializer {
        require(_mpc != address(0));
        mpc = _mpc;
        _addOperator(_mpc);
        c3caller = _c3caller;
        __UUPSUpgradeable_init();
        __Ownable_init();
        transferOwnership(_mpc);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function changeMPC(address _mpc) external onlyOwner {
        pendingMPC = _mpc;
    }

    function applyMPC() external {
        require(msg.sender == pendingMPC);
        mpc = pendingMPC;
        pendingMPC = address(0);
    }

    function _addOperator(address op) internal {
        require(op != address(0), "C3Caller: Operator is address(0)");
        require(!isOperator[op], "C3Caller: Operator already exists");
        isOperator[op] = true;
        operators.push(op);
    }

    function addOperator(address _auth) external onlyOwner {
        _addOperator(_auth);
    }

    function getAllOperators() external view returns (address[] memory) {
        return operators;
    }

    function revokeOperator(address _auth) external onlyOwner {
        require(isOperator[_auth], "C3Caller: Operator not found");
        isOperator[_auth] = false;
        uint256 length = operators.length;
        for (uint256 i = 0; i < length; i++) {
            if (operators[i] == _auth) {
                operators[i] = operators[length - 1];
                operators.pop();
                return;
            }
        }
    }

    function isExecutor(address sender) external view override returns (bool) {
        return isOperator[sender];
    }

    function isCaller(address sender) external view override returns (bool) {
        return sender == c3caller;
    }

    function context()
        external
        view
        override
        returns (
            bytes32 swapID,
            string memory fromChainID,
            string memory sourceTx
        )
    {
        return IC3Caller(c3caller).context();
    }

    function c3call(
        uint256 _dappID,
        string calldata _to,
        string calldata _toChainID,
        bytes calldata _data
    ) external override {
        IC3Caller(c3caller).c3call(_dappID, msg.sender, _to, _toChainID, _data);
    }

    function c3broadcast(
        uint256 _dappID,
        string calldata _to,
        string[] calldata _toChainIDs,
        bytes calldata _data
    ) external override {
        IC3Caller(c3caller).c3broadcast(
            _dappID,
            msg.sender,
            _to,
            _toChainIDs,
            _data
        );
    }

    function execute(
        uint256 _dappID,
        bytes32 _swapID,
        address _to,
        string calldata _fromChainID,
        string calldata _sourceTx,
        string calldata _fallback,
        bytes calldata _data
    ) external override onlyAuth {
        IC3Caller(c3caller).execute(
            _dappID,
            _swapID,
            _to,
            _fromChainID,
            _sourceTx,
            _fallback,
            _data
        );
    }

    function c3Fallback(
        uint256 _dappID,
        bytes32 _swapID,
        address _to,
        string calldata _failChainID,
        string calldata _failTx,
        bytes calldata _data,
        bytes calldata _reason
    ) external override onlyAuth {
        IC3Caller(c3caller).c3Fallback(
            _dappID,
            _swapID,
            _to,
            _failChainID,
            _failTx,
            _data,
            _reason
        );
    }
}
