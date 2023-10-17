// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract C3Caller {
    // App config
    struct AppConfig {
        address app; // the application contract address
        address appAdmin; // account who admin the application's config
        uint256 appFlags; // flags of the application
    }

    // Src fee is (baseFees + msg.data.length*feesPerByte)
    struct SrcFeeConfig {
        uint256 baseFees;
        uint256 feesPerByte;
    }

    uint256 public constant APP_FEE_SRC = 1; // src chain pay the fee
    uint256 public constant APP_FEE_DEST = 2; // dest chain pay the fee
    uint256 constant EXECUTION_OVERHEAD = 100000;
    uint256 public destFeeRate = 500; // 100000
    uint256 public constant FEERATE_DENOMINATOR = 100000;

    // key is app address
    mapping(address => string) public appIdentifier;

    // key is appID, a unique identifier for each project
    mapping(string => AppConfig) public appConfig;
    mapping(address => string) public appExecWhitelist;
    mapping(string => bool) public appBlacklist;
    mapping(uint256 => SrcFeeConfig) public srcDefaultFees; // key is chainID
    mapping(string => mapping(uint256 => SrcFeeConfig)) public srcCustomFees;

    uint256 public accruedFees;
    uint256 public minReserveBudget = 0.01 ether;
    mapping(string => uint256) public executionBudget;

    address public mpc;
    address public pendingMPC;

    mapping(address => bool) public isRouter;
    address[] public c3routers;

    /// @dev Access control function
    modifier onlyMPC() {
        require(msg.sender == mpc, "C3Call: only MPC");
        _;
    }

    /// @dev Access control function
    modifier onlyC3Router() {
        require(isRouter[msg.sender], "C3Call: only C3Router");
        _;
    }

    event Deposit(address indexed account, uint256 amount, string appID);
    event Withdraw(address indexed account, uint256 amount, string appID);
    event SetBlacklists(string[] appID, bool flag);
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
    event SetAppConfig(
        string appID,
        address app,
        address appAdmin,
        uint256 appFlags
    );
    event UpgradeApp(string appID, address oldApp, address newApp);
    event IncrFee(string appID, uint256 fee, uint256 gas);

    constructor(address _mpc) {
        require(_mpc != address(0));
        mpc = _mpc;
        emit ApplyMPC(address(0), _mpc, block.timestamp);
    }

    receive() external payable {}

    fallback() external payable {}

    function checkCall(
        address _sender,
        uint256 _datalength,
        uint256 _toChainID
    ) external view returns (string memory _appID, uint256 _srcFees) {
        _appID = appIdentifier[_sender];
        require(appConfig[_appID].appFlags > 0, "C3Call: app not exist");
        require(!appBlacklist[_appID], "C3Call: in blacklist");
        if (appConfig[_appID].appFlags == APP_FEE_SRC) {
            _srcFees = _calcSrcFees(_appID, _toChainID, _datalength);
        } else {
            _srcFees = 0;
        }
    }

    function checkExec(address _to) external view {
        string memory _appID = appExecWhitelist[_to];
        require(appConfig[_appID].appFlags > 0, "C3Call: app not exist");
        require(!appBlacklist[_appID], "C3Call: in blacklist");
        require(
            executionBudget[_appID] >= minReserveBudget,
            "less than min budget"
        );
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

    function addRouter(address _router) external onlyMPC {
        require(_router != address(0), "C3Call: Router is address(0)");
        require(!isRouter[_router], "C3Call: Router already exists");
        isRouter[_router] = true;
        c3routers.push(_router);
    }

    function getAllRouters() external view returns (address[] memory) {
        return c3routers;
    }

    function removeRouter(address _router) external onlyMPC {
        require(isRouter[_router], "C3Call: Router not found");
        isRouter[_router] = false;
        uint256 length = c3routers.length;
        for (uint256 i = 0; i < length; i++) {
            if (c3routers[i] == _router) {
                c3routers[i] = c3routers[length - 1];
                c3routers.pop();
                return;
            }
        }
    }

    function setMinReserveBudget(uint128 _minBudget) external onlyMPC {
        minReserveBudget = _minBudget;
    }

    function setDestFeeRate(uint256 _destFeeRate) external onlyMPC {
        destFeeRate = _destFeeRate;
    }

    function deposit(string calldata _appID) external payable {
        AppConfig memory config = appConfig[_appID];
        require(config.appFlags > 0, "C3Call: app not exist");
        executionBudget[_appID] += msg.value;
        emit Deposit(msg.sender, msg.value, _appID);
    }

    function withdraw(string calldata _appID, uint256 _amount) external {
        AppConfig memory config = appConfig[_appID];
        require(msg.sender == config.appAdmin, "C3Call: forbid");
        executionBudget[_appID] -= _amount;
        emit Withdraw(msg.sender, _amount, _appID);
        (bool success, ) = msg.sender.call{value: _amount}("");
        require(success);
    }

    function withdrawFees() external onlyMPC {
        uint256 fees = accruedFees;
        accruedFees = 0;
        (bool success, ) = mpc.call{value: fees}("");
        require(success);
    }

    function initAppConfig(
        string calldata _appID,
        address _app,
        address _admin,
        uint256 _flags,
        address[] calldata _whitelist
    ) external onlyMPC {
        require(bytes(_appID).length > 0);
        require(_app != address(0));

        AppConfig storage config = appConfig[_appID];
        require(config.app == address(0), "C3Call: app exist");
        require(
            _flags == APP_FEE_SRC || _flags == APP_FEE_DEST,
            "C3Call: _flags is invalid"
        );

        appIdentifier[_app] = _appID;

        config.app = _app;
        config.appAdmin = _admin;
        config.appFlags = _flags;

        address[] memory whitelist = new address[](1 + _whitelist.length);
        whitelist[0] = _app;
        for (uint256 i = 0; i < _whitelist.length; i++) {
            whitelist[i + 1] = _whitelist[i];
        }

        _setAppWhitelist(_appID, whitelist);

        emit SetAppConfig(_appID, _app, _admin, _flags);
    }

    function _setAppWhitelist(
        string memory _appID,
        address[] memory _whitelist
    ) internal {
        for (uint256 i = 0; i < _whitelist.length; i++) {
            appExecWhitelist[_whitelist[i]] = _appID;
        }
    }

    function setWhitelists(address _app, address[] memory _whitelist) external {
        string memory _appID = appIdentifier[_app];
        AppConfig storage config = appConfig[_appID];

        require(
            config.app == _app && _app != address(0),
            "C3Call: app not exist"
        );
        require(
            msg.sender == mpc || msg.sender == config.appAdmin,
            "C3Call: forbid"
        );

        _setAppWhitelist(_appID, _whitelist);
    }

    function delWhitelists(address _app, address[] memory _whitelist) external {
        string memory _appID = appIdentifier[_app];
        AppConfig storage config = appConfig[_appID];

        require(
            config.app == _app && _app != address(0),
            "C3Call: app not exist"
        );
        require(
            msg.sender == mpc || msg.sender == config.appAdmin,
            "C3Call: forbid"
        );

        _setAppWhitelist("", _whitelist);
    }

    function updateAppConfig(
        address _app,
        address _admin,
        uint256 _flags
    ) external {
        string memory _appID = appIdentifier[_app];
        AppConfig storage config = appConfig[_appID];

        require(
            config.app == _app && _app != address(0),
            "C3Call: app not exist"
        );
        require(
            msg.sender == mpc || msg.sender == config.appAdmin,
            "C3Call: forbid"
        );
        require(
            _flags == APP_FEE_SRC || _flags == APP_FEE_DEST,
            "C3Call: _flags is invalid"
        );

        if (_admin != address(0)) {
            config.appAdmin = _admin;
        }
        config.appFlags = _flags;

        emit SetAppConfig(_appID, _app, _admin, _flags);
    }

    function upgradeApp(address _oldApp, address _newApp) external {
        string memory _appID = appIdentifier[_oldApp];
        AppConfig storage config = appConfig[_appID];

        require(
            config.app == _oldApp && _oldApp != address(0),
            "C3Call: app not exist"
        );
        require(
            msg.sender == mpc || msg.sender == config.appAdmin,
            "C3Call: forbid"
        );
        require(bytes(appIdentifier[_newApp]).length == 0, "C3Call: inited");

        config.app = _newApp;

        emit UpgradeApp(_appID, _oldApp, _newApp);
    }

    function setBlacklists(
        string[] calldata _appIDs,
        bool _flag
    ) external onlyMPC {
        for (uint256 i = 0; i < _appIDs.length; i++) {
            appBlacklist[_appIDs[i]] = _flag;
        }
        emit SetBlacklists(_appIDs, _flag);
    }

    function setDefaultSrcFees(
        uint256[] calldata _toChainIDs,
        uint256[] calldata _baseFees,
        uint256[] calldata _feesPerByte
    ) external onlyMPC {
        uint256 length = _toChainIDs.length;
        require(length == _baseFees.length && length == _feesPerByte.length);

        for (uint256 i = 0; i < length; i++) {
            srcDefaultFees[_toChainIDs[i]] = SrcFeeConfig(
                _baseFees[i],
                _feesPerByte[i]
            );
        }
    }

    function setCustomSrcFees(
        address _app,
        uint256[] calldata _toChainIDs,
        uint256[] calldata _baseFees,
        uint256[] calldata _feesPerByte
    ) external onlyMPC {
        string memory _appID = appIdentifier[_app];
        AppConfig storage config = appConfig[_appID];

        require(
            config.app == _app && _app != address(0),
            "C3Call: app not exist"
        );

        uint256 length = _toChainIDs.length;
        require(length == _baseFees.length && length == _feesPerByte.length);

        mapping(uint256 => SrcFeeConfig) storage _srcFees = srcCustomFees[
            _appID
        ];
        for (uint256 i = 0; i < length; i++) {
            _srcFees[_toChainIDs[i]] = SrcFeeConfig(
                _baseFees[i],
                _feesPerByte[i]
            );
        }
    }

    function payDestFees(
        address _to,
        uint256 _prevGasLeft
    ) external onlyC3Router {
        string memory _appID = appExecWhitelist[_to];
        AppConfig memory config = appConfig[_appID];
        require(config.appFlags == APP_FEE_DEST, "C3Call: app not exist");
        uint256 gasUsed = _prevGasLeft - gasleft();
        uint256 totalCost = ((gasUsed + EXECUTION_OVERHEAD) *
            tx.gasprice *
            (FEERATE_DENOMINATOR + destFeeRate)) / FEERATE_DENOMINATOR;
        uint256 budget = executionBudget[_appID];
        require(budget > totalCost, "C3Call: no enough budget");
        executionBudget[_appID] = budget - totalCost;
        accruedFees += totalCost;
        emit IncrFee(_appID, totalCost, gasUsed * tx.gasprice);
    }

    function paySrcFees(
        address _sender,
        uint256 _fees
    ) external payable onlyC3Router {
        string memory _appID = appIdentifier[_sender];
        require(_fees > 0, "C3Call: no enough src fee");
        require(msg.value >= _fees, "C3Call: no enough src fee");
        accruedFees += _fees;
        emit IncrFee(_appID, _fees, _fees);
    }

    function calcSrcFees(
        address _app,
        uint256 _toChainID,
        uint256 _dataLength
    ) external view returns (uint256) {
        string memory _appID = appIdentifier[_app];
        return _calcSrcFees(_appID, _toChainID, _dataLength);
    }

    function calcSrcFeesByApp(
        string calldata _appID,
        uint256 _toChainID,
        uint256 _dataLength
    ) external view returns (uint256) {
        return _calcSrcFees(_appID, _toChainID, _dataLength);
    }

    function _calcSrcFees(
        string memory _appID,
        uint256 _toChainID,
        uint256 _dataLength
    ) internal view returns (uint256) {
        SrcFeeConfig memory customFees = srcCustomFees[_appID][_toChainID];
        uint256 customBaseFees = customFees.baseFees;
        uint256 customFeesPerBytes = customFees.feesPerByte;

        SrcFeeConfig memory defaultFees = srcDefaultFees[_toChainID];
        uint256 defaultBaseFees = defaultFees.baseFees;
        uint256 defaultFeesPerBytes = defaultFees.feesPerByte;

        uint256 baseFees = (customBaseFees > defaultBaseFees)
            ? customBaseFees
            : defaultBaseFees;
        uint256 feesPerByte = (customFeesPerBytes > defaultFeesPerBytes)
            ? customFeesPerBytes
            : defaultFeesPerBytes;

        return baseFees + _dataLength * feesPerByte;
    }

    function _payDestFees(uint256 fees) internal {
        require(msg.value >= fees, "C3Call: no enough src fee");
        accruedFees += fees;
        if (msg.value > fees) {
            // return remaining amount
            (bool success, ) = msg.sender.call{value: msg.value - fees}("");
            require(success);
        }
    }
}
