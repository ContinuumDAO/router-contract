// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract C3DappManager is Pausable, Ownable {
    // Dapp config
    struct DappConfig {
        uint256 id;
        address appAdmin; // account who admin the application's config
        address feeToken; // token address for fee token
        uint256 discount; // discount
    }
    struct FeeConfig {
        uint256 swapFee;
        uint256 callPerByteFee;
    }
    address public mpc;
    address public pendingMPC;

    uint256 public dappID;

    mapping(uint256 => DappConfig) private dappConfig;
    mapping(string => uint256) private c3DappAddr;
    mapping(uint256 => bool) private appBlacklist;

    mapping(address => FeeConfig) public feeCurrencies;
    mapping(uint256 => mapping(address => uint256)) public dappStakePool;

    mapping(string => mapping(address => FeeConfig)) public speChainFees;

    mapping(address => uint256) private fees;

    event ChangeMPC(
        address indexed oldMPC,
        address indexed newMPC,
        uint256 timestamp
    );
    event ApplyMPC(
        address indexed oldMPC,
        address indexed newMPC,
        uint256 timestamp
    );
    event SetDAppConfig(
        uint256 indexed dappID,
        address indexed appAdmin,
        address indexed feeToken,
        string appDomain,
        string email
    );
    event SetBlacklists(uint256 dappID, bool flag);

    event SetDAppAddr(uint256 indexed dappID, string[] addresses);

    event SetFeeConfig(
        address indexed token,
        string chain,
        uint256 swapFee,
        uint256 callPerByteFee
    );

    event Deposit(
        uint256 indexed dappID,
        address indexed token,
        uint256 amount
    );
    event Withdraw(
        uint256 indexed dappID,
        address indexed token,
        uint256 amount
    );
    event Charging(
        uint256 indexed dappID,
        address indexed token,
        uint256 bill,
        uint256 amount,
        uint256 left
    );

    constructor(address _mpc) {
        require(_mpc != address(0));
        mpc = _mpc;
        _transferOwnership(mpc);
    }

    modifier onlyMPC() {
        require(msg.sender == mpc, "C3Dapp: only MPC");
        _;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function changeMPC(address _mpc) external onlyMPC {
        pendingMPC = _mpc;
        emit ChangeMPC(mpc, _mpc, block.timestamp);
    }

    function applyMPC() external {
        require(msg.sender == pendingMPC);
        emit ApplyMPC(mpc, pendingMPC, block.timestamp);
        mpc = pendingMPC;
        pendingMPC = address(0);
    }

    function setBlacklists(uint256 _dappID, bool _flag) external onlyMPC {
        appBlacklist[_dappID] = _flag;
        emit SetBlacklists(_dappID, _flag);
    }

    function setFeeCurrencies(
        address[] calldata _tokens,
        uint256[] calldata _swapfee,
        uint256[] calldata _callfee
    ) external onlyMPC {
        for (uint256 index = 0; index < _tokens.length; index++) {
            feeCurrencies[_tokens[index]] = FeeConfig(
                _swapfee[index],
                _callfee[index]
            );
            emit SetFeeConfig(
                _tokens[index],
                "0",
                _swapfee[index],
                _callfee[index]
            );
        }
    }

    function disableFeeCurrency(address _token) external onlyMPC {
        delete feeCurrencies[_token];
        emit SetFeeConfig(_token, "0", 0, 0);
    }

    function setSpeFeeConfigByChain(
        address _token,
        string calldata _chain,
        uint256 _fee,
        uint256 _callfee
    ) external onlyMPC {
        speChainFees[_chain][_token] = FeeConfig(_fee, _callfee);
        emit SetFeeConfig(_token, _chain, _fee, _callfee);
    }

    function initDappConfig(
        address _feeToken,
        string calldata _appDomain,
        string calldata _email,
        string[] calldata _whitelist
    ) external {
        require(
            feeCurrencies[_feeToken].swapFee > 0,
            "C3Dapp: fee token not supported"
        );

        dappID++;
        DappConfig storage config = dappConfig[dappID];
        config.id = dappID;
        config.appAdmin = msg.sender;
        config.feeToken = _feeToken;

        _setDappAddrlist(dappID, _whitelist);

        emit SetDAppConfig(dappID, msg.sender, _feeToken, _appDomain, _email);
    }

    function _setDappAddrlist(
        uint256 _subscribeID,
        string[] memory _whitelist
    ) internal {
        for (uint256 i = 0; i < _whitelist.length; i++) {
            require(
                c3DappAddr[_whitelist[i]] == 0,
                "C3Dapp: addr already exist"
            );
            c3DappAddr[_whitelist[i]] = _subscribeID;
        }
        emit SetDAppAddr(_subscribeID, _whitelist);
    }

    function addDappAddr(uint256 _dappID, string[] memory _whitelist) external {
        DappConfig memory config = dappConfig[_dappID];

        require(config.appAdmin != address(0), "C3Dapp: app not exist");
        require(
            msg.sender == mpc || msg.sender == config.appAdmin,
            "C3Dapp: forbid"
        );

        _setDappAddrlist(_dappID, _whitelist);
    }

    function delWhitelists(
        uint256 _dappID,
        string[] memory _whitelist
    ) external {
        DappConfig memory config = dappConfig[_dappID];

        require(config.appAdmin != address(0), "C3Dapp: app not exist");
        require(
            msg.sender == mpc || msg.sender == config.appAdmin,
            "C3Dapp: forbid"
        );

        for (uint256 i = 0; i < _whitelist.length; i++) {
            require(
                c3DappAddr[_whitelist[i]] == _dappID,
                "C3Dapp: addr not exist"
            );
            c3DappAddr[_whitelist[i]] = 0;
        }
        emit SetDAppAddr(0, _whitelist);
    }

    function updateDAppConfig(
        uint256 _dappID,
        address _feeToken,
        string calldata _appID,
        string calldata _email
    ) external {
        DappConfig memory config = dappConfig[_dappID];

        require(config.appAdmin != address(0), "C3Dapp: app not exist");
        require(
            msg.sender == mpc || msg.sender == config.appAdmin,
            "C3Dapp: forbid"
        );
        require(
            feeCurrencies[_feeToken].swapFee > 0,
            "C3Dapp: fee token not supported"
        );

        config.feeToken = _feeToken;

        emit SetDAppConfig(dappID, msg.sender, _feeToken, _appID, _email);
    }

    function resetAdmin(uint256 _dappID, address _newAdmin) external {
        DappConfig storage config = dappConfig[_dappID];

        require(config.appAdmin != address(0), "C3Dapp: app not exist");
        require(
            msg.sender == mpc || msg.sender == config.appAdmin,
            "C3Dapp: forbid"
        );
        config.appAdmin = _newAdmin;
    }

    function updateDappByMPC(
        uint256 _dappID,
        address _feeToken,
        uint256 _discount
    ) external onlyMPC {
        DappConfig storage config = dappConfig[_dappID];

        require(config.appAdmin != address(0), "C3Dapp: app not exist");
        require(
            feeCurrencies[_feeToken].swapFee > 0,
            "C3Dapp: fee token not supported"
        );

        config.feeToken = _feeToken;
        config.discount = _discount;

        emit SetDAppConfig(dappID, config.appAdmin, _feeToken, "", "");
    }

    function deposit(
        uint256 _dappID,
        address _token,
        uint256 _amount
    ) external {
        DappConfig memory config = dappConfig[_dappID];
        require(config.id > 0, "C3Dapp: dapp not exist");
        require(config.appAdmin == msg.sender, "C3Dapp: forbidden");
        require(
            feeCurrencies[_token].swapFee > 0,
            "C3Dapp: fee token not supported"
        );
        uint256 old_balance = IERC20(_token).balanceOf(address(this));
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        uint256 new_balance = IERC20(_token).balanceOf(address(this));
        require(
            new_balance >= old_balance && new_balance <= old_balance + _amount
        );
        uint256 balance = new_balance - old_balance;

        dappStakePool[_dappID][_token] += balance;
        emit Deposit(_dappID, _token, balance);
    }

    function withdraw(
        uint256 _dappID,
        address _token,
        uint256 _amount
    ) external {
        require(
            dappStakePool[_dappID][_token] >= _amount,
            "C3Dapp: insufficient amount for dapp"
        );
        require(
            IERC20(_token).balanceOf(address(this)) >= _amount,
            "C3Dapp: insufficient amount for request"
        );
        DappConfig memory config = dappConfig[_dappID];
        require(msg.sender == config.appAdmin, "C3Dapp: forbid");
        require(
            IERC20(_token).transfer(msg.sender, _amount),
            "C3Dapp: transfer not successful"
        );
        dappStakePool[_dappID][_token] -= _amount;
        emit Withdraw(_dappID, _token, _amount);
    }

    function charging(
        uint256[] calldata _dappIDs,
        address[] calldata _tokens,
        uint256[] calldata _amounts
    ) external onlyMPC {
        require(
            _dappIDs.length == _tokens.length &&
                _dappIDs.length == _amounts.length,
            "C3Dapp: length mismatch"
        );

        for (uint256 index = 0; index < _dappIDs.length; index++) {
            uint256 _dappID = _dappIDs[index];
            address _token = _tokens[index];
            uint256 _amount = _amounts[index];
            if (dappStakePool[_dappID][_token] > _amount) {
                dappStakePool[_dappID][_token] -= _amount;
            } else {
                _amount = dappStakePool[_dappID][_token];
                dappStakePool[_dappID][_token] = 0;
            }
            fees[_token] += _amount;
            emit Charging(
                _dappID,
                _token,
                _amounts[index],
                _amount,
                dappStakePool[_dappID][_token]
            );
        }
    }

    function withdrawFees(address[] calldata _tokens) external onlyMPC {
        for (uint256 index = 0; index < _tokens.length; index++) {
            if (fees[_tokens[index]] > 0) {
                IERC20(_tokens[index]).transfer(mpc, fees[_tokens[index]]);
                fees[_tokens[index]] = 0;
            }
        }
    }
}
