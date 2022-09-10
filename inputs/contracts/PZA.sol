// SPDX-License-Identifier: MIT


pragma solidity ^0.8.0;


import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "hardhat/console.sol";

contract PZA is ERC20, Ownable {
    using SafeMath for uint256;

    // Default percent to charge on each transfer (Note: 1e18 == 100%)
    uint256 private _transactionFeePercent;
    // Default percent to charge when selling tokens (Note: 1e18 == 100%)
    uint256 private _transactionFeePercentOwner;


    mapping(address => bool) whitelistAddresses;


    // Timelcok feature
    enum Functions {FEE, FEE_OWNER, FEE_DIST}
    uint256 private constant _TIMELOCK = 0 days;
    mapping(Functions => uint256) public currentTimelocks;
    mapping(Functions => bool) public hasPendingFee;

    
    // Fee Beneficiaries
	address public _DevelopmentWallet;
	address public _MarketingWallet;
	address public _RewardsWallet;
	address public _LiquidityWallet;

    // Percent distribution among wallets and burn
    // Note: The sum of these four values should be 100% (1e18)
	uint256 public _DevelopmentWalletFeePercent;
	uint256 public _MarketingWalletFeePercent;
	uint256 public _RewardsWalletFeePercent;
	uint256 public _LiquidityWalletFeePercent;


    // Proposal Variables
    uint256 private _pendingTransactionFeePercent;
    uint256 private _pendingTransactionFeePercentOwner;


	uint256 public _pendingDevelopmentWalletFeePercent;
	uint256 public _pendingMarketingWalletFeePercent;
	uint256 public _pendingRewardsWalletFeePercent;
	uint256 public _pendingLiquidityWalletFeePercent;


    uint256 private _feeUpdateTimestamp;

    constructor(
		address DevelopmentWallet,
		address MarketingWallet,
		address RewardsWallet,
		address LiquidityWallet
    ) ERC20("Pizza", "PZA") {
        _mint(_msgSender(), 1000);

		_transactionFeePercent = 15e16; // 15%


		_DevelopmentWallet = DevelopmentWallet;
		_MarketingWallet = MarketingWallet;
		_RewardsWallet = RewardsWallet;
		_LiquidityWallet = LiquidityWallet;


		_DevelopmentWalletFeePercent = 25e16; //25%
		_MarketingWalletFeePercent = 25e16; //25%
		_RewardsWalletFeePercent = 25e16; //25%
		_LiquidityWalletFeePercent = 25e16; //25%


        // initialize timelock conditions
        currentTimelocks[Functions.FEE] = 0;
        currentTimelocks[Functions.FEE_OWNER] = 0;
        currentTimelocks[Functions.FEE_DIST] = 0;

        hasPendingFee[Functions.FEE] = false;
        hasPendingFee[Functions.FEE_OWNER] = false;
        hasPendingFee[Functions.FEE_DIST] = false;

        //add PZA wallets to whitelistAddresses
        addWhitelistAddress(_msgSender());
		addWhitelistAddress(_DevelopmentWallet);
		addWhitelistAddress(_MarketingWallet);
		addWhitelistAddress(_RewardsWallet);
		addWhitelistAddress(_LiquidityWallet);

    }

    // TODO: Mitigate Contract owner from front-run transfers with fee changes
    // Consider modifing fees with a time lock approach. An initial transaction could specify the new fees,
    // and a subsequent transaction (which must be more than a fixed number of blocks later) can then update the fees.

    // Transfer functions with fee charging
    //

    function transfer(address recipient, uint256 amount)
        public
        override
        updateFees()
        returns (bool)
    {
        _transferWithFee(_msgSender(), recipient, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override updateFees() returns (bool) {
        _transferWithFee(sender, recipient, amount);

        uint256 currentAllowance = allowance(sender, _msgSender());
        require(
            currentAllowance >= amount,
            "BEP20: transfer amount exceeds allowance"
        );
        unchecked {_approve(sender, _msgSender(), currentAllowance - amount);}

        return true;
    }

    function _transferWithFee(
        address sender,
        address recipient,
        uint256 amount
    ) private {
        uint256 feeToCharge;
        //check whitelist first
            if (whitelistAddresses[sender] || whitelistAddresses[recipient]) {
                feeToCharge = amount.mul(_transactionFeePercentOwner).div(1e18);
            } else {
                feeToCharge = amount.mul(_transactionFeePercent).div(1e18);
            }

            uint256 amountAfterFee = amount.sub(feeToCharge);

            (
				uint256 toDevelopment,
				uint256 toMarketing,
				uint256 toRewards,
				uint256 toLiquidity
            ) = calculateFeeDistribution(feeToCharge);

			_transfer(sender, _DevelopmentWallet, toDevelopment);
			_transfer(sender, _MarketingWallet, toMarketing);
			_transfer(sender, _RewardsWallet, toRewards);
			_transfer(sender, _LiquidityWallet, toLiquidity);
            _transfer(sender, recipient, amountAfterFee);
    }

// Calculate Fee distributions

    function calculateFeeDistribution(uint256 amount)
        private
        view
        returns (
			uint256 toDevelopment,
			uint256 toMarketing,
			uint256 toRewards,
			uint256 toLiquidity
        )
    {
		toDevelopment = amount.mul(_DevelopmentWalletFeePercent).div(1e18);
		toMarketing = amount.mul(_MarketingWalletFeePercent).div(1e18);
		toRewards = amount.mul(_RewardsWalletFeePercent).div(1e18);
		toLiquidity = amount.mul(_LiquidityWalletFeePercent).div(1e18);


    }

    // Note: run this code before transfers (from modifier or function's body)
    modifier updateFees() {
        setTransactionFee();
        setTransactionFeeOwner();
        setFeeDistribution();
        _;
    }

    // Getters for Current Transaction fees / distributions

    function getCurrentTransactionFee() public view returns (uint256) {
        return _transactionFeePercent;
    }

    function getCurrentTransactionFeeOwner() public view returns (uint256) {
        return _transactionFeePercentOwner;
    }

    function getCurrentFeeDistribution()
        public
        view
        returns (
			uint256,
			uint256,
			uint256,
			uint256
        )
    {
        return (
			_DevelopmentWalletFeePercent,
			_MarketingWalletFeePercent,
			_RewardsWalletFeePercent,
			_LiquidityWalletFeePercent
        );
    }

    // Getters for Pending Transaction fees / distributions

    function getPendingTransactionFee() public view returns (uint256) {
        return _pendingTransactionFeePercent;
    }

    function getPendingTransactionFeeOwner() public view returns (uint256) {
        return _pendingTransactionFeePercentOwner;
    }

    function getPendingFeeDistribution()
        public
        view
        returns (
			uint256,
			uint256,
			uint256,
			uint256
        )
    {
        return (
			_pendingDevelopmentWalletFeePercent,
			_pendingMarketingWalletFeePercent,
			_pendingRewardsWalletFeePercent,
			_pendingLiquidityWalletFeePercent
        );
    }

    // Getters for Pending Transaction fees / distributions

    function getPendingTransactionFeeTime() public view returns (uint256) {
        return currentTimelocks[Functions.FEE];
    }

    function getPendingTransactionFeeOwnerTime() public view returns (uint256) {
        return currentTimelocks[Functions.FEE_OWNER];
    }

    function getPendingFeeDistributionTime() public view returns (uint256) {
        return currentTimelocks[Functions.FEE_DIST];
    }

    

    //
    // Administration setter functions
    //

    function proposeTransactionFee(uint256 fee) public onlyOwner {
        require(
            fee >= 0 && fee <= 15e16,
            "PZA: transaction fee should be >= 0 and <= 15%"
        );
        require(
            !hasPendingFee[Functions.FEE],
            "PZA: There is a pending fee change already."
        );
        require(
            currentTimelocks[Functions.FEE] == 0,
            "Current Timelock is already initialized with a value"
        );

        _pendingTransactionFeePercent = fee;

        // intialize timelock conditions
        currentTimelocks[Functions.FEE] = block.timestamp + _TIMELOCK; // resets timelock with future timestamp that it will be unlocked
        hasPendingFee[Functions.FEE] = true;
    }

    function proposeTransactionFeeOwner(uint256 fee) public onlyOwner {
        require(
            fee >= 0 && fee <= 15e16,
            "PZA: sell transaction fee should be >= 0 and <= 15%"
        );
        require(
            !hasPendingFee[Functions.FEE_OWNER],
            "PZA: There is a pending owner fee change already."
        );
        require(
            currentTimelocks[Functions.FEE_OWNER] == 0,
            "Current Timelock is already initialized with a value"
        );

        _pendingTransactionFeePercentOwner = fee;

        // intialize timelock conditions
        currentTimelocks[Functions.FEE_OWNER] = block.timestamp + _TIMELOCK; // resets timelock with future timestamp that it will be unlocked
        hasPendingFee[Functions.FEE_OWNER] = true;
    }

    function proposeFeeDistribution(
			uint256 DevelopmentWalletFeePercent,
			uint256 MarketingWalletFeePercent,
			uint256 RewardsWalletFeePercent,
			uint256 LiquidityWalletFeePercent
    ) public onlyOwner {
        require(
				DevelopmentWalletFeePercent
				.add(MarketingWalletFeePercent)
				.add(RewardsWalletFeePercent)
				.add(LiquidityWalletFeePercent) == 1e18,
            "PZA: The sum of distribuition should be 100%"
        );
        require(
            !hasPendingFee[Functions.FEE_DIST],
            "PZA: There is a pending dsitribution fee change already."
        );
        require(
            currentTimelocks[Functions.FEE_DIST] == 0,
            "Current Timelock is already initialized with a value"
        );
			_pendingDevelopmentWalletFeePercent = _DevelopmentWalletFeePercent;
			_pendingMarketingWalletFeePercent = _MarketingWalletFeePercent;
			_pendingRewardsWalletFeePercent = _RewardsWalletFeePercent;
			_pendingLiquidityWalletFeePercent = _LiquidityWalletFeePercent;

        // intialize timelock conditions
        currentTimelocks[Functions.FEE_DIST] = block.timestamp + _TIMELOCK;
        hasPendingFee[Functions.FEE_DIST] = true;
    }

    function setTransactionFee() private {
        if (
            hasPendingFee[Functions.FEE] == true &&
            currentTimelocks[Functions.FEE] <= block.timestamp
        ) {
            _transactionFeePercent = _pendingTransactionFeePercent;

            // reset timelock conditions
            currentTimelocks[Functions.FEE] = 0;
            hasPendingFee[Functions.FEE] = false;
        }
    }

    function setTransactionFeeOwner() private {
        if (
            hasPendingFee[Functions.FEE_OWNER] == true &&
            currentTimelocks[Functions.FEE_OWNER] <= block.timestamp
        ) {
            _transactionFeePercentOwner = _pendingTransactionFeePercentOwner;

            // reset timelock conditions
            currentTimelocks[Functions.FEE_OWNER] = 0;
            hasPendingFee[Functions.FEE_OWNER] = false;
        }
    }

    function setFeeDistribution() private {
        if (
            hasPendingFee[Functions.FEE_DIST] == true &&
            currentTimelocks[Functions.FEE_DIST] <= block.timestamp
        ) {
			_DevelopmentWalletFeePercent = _pendingDevelopmentWalletFeePercent;
			_MarketingWalletFeePercent = _pendingMarketingWalletFeePercent;
			_RewardsWalletFeePercent = _pendingRewardsWalletFeePercent;
			_LiquidityWalletFeePercent = _pendingLiquidityWalletFeePercent;

            // reset timelock conditions
            currentTimelocks[Functions.FEE_DIST] = 0;
            hasPendingFee[Functions.FEE_DIST] = false;
        }
    }

	function setDevelopmentWalletAddress(address DevelopmentAddress) public onlyOwner {
	require(
		DevelopmentAddress != address(0),
		"PZA: DevelopmentAddress cannot be zero address"
	);
	_DevelopmentWallet = DevelopmentAddress;
}
	function setMarketingWalletAddress(address MarketingAddress) public onlyOwner {
	require(
		MarketingAddress != address(0),
		"PZA: MarketingAddress cannot be zero address"
	);
	_MarketingWallet = MarketingAddress;
}
	function setRewardsWalletAddress(address RewardsAddress) public onlyOwner {
	require(
		RewardsAddress != address(0),
		"PZA: RewardsAddress cannot be zero address"
	);
	_RewardsWallet = RewardsAddress;
}
	function setLiquidityWalletAddress(address LiquidityAddress) public onlyOwner {
	require(
		LiquidityAddress != address(0),
		"PZA: LiquidityAddress cannot be zero address"
	);
	_LiquidityWallet = LiquidityAddress;
}

    function addWhitelistAddress(address companyAddress) public onlyOwner {
        whitelistAddresses[companyAddress] = true;
    }

    function removeWhitelistAddress(address companyAddress) public onlyOwner {
        require(
            whitelistAddresses[companyAddress] == true,
            "The company address you're trying to remove does not exist or already has been removed"
        );
        whitelistAddresses[companyAddress] = false;
    }




}
// SPDX-License-Identifier: MIT


pragma solidity ^0.8.0;


import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "hardhat/console.sol";

contract PZA is ERC20, Ownable {
    using SafeMath for uint256;

    // Default percent to charge on each transfer (Note: 1e18 == 100%)
    uint256 private _transactionFeePercent;
    // Default percent to charge when selling tokens (Note: 1e18 == 100%)
    uint256 private _transactionFeePercentOwner;


    mapping(address => bool) whitelistAddresses;


    // Timelcok feature
    enum Functions {FEE, FEE_OWNER, FEE_DIST}
    uint256 private constant _TIMELOCK = 0 days;
    mapping(Functions => uint256) public currentTimelocks;
    mapping(Functions => bool) public hasPendingFee;

    
    // Fee Beneficiaries
	address public _DevelopmentWallet;
	address public _MarketingWallet;
	address public _RewardsWallet;
	address public _LiquidityWallet;

    // Percent distribution among wallets and burn
    // Note: The sum of these four values should be 100% (1e18)
	uint256 public _DevelopmentWalletFeePercent;
	uint256 public _MarketingWalletFeePercent;
	uint256 public _RewardsWalletFeePercent;
	uint256 public _LiquidityWalletFeePercent;


    // Proposal Variables
    uint256 private _pendingTransactionFeePercent;
    uint256 private _pendingTransactionFeePercentOwner;


	uint256 public _pendingDevelopmentWalletFeePercent;
	uint256 public _pendingMarketingWalletFeePercent;
	uint256 public _pendingRewardsWalletFeePercent;
	uint256 public _pendingLiquidityWalletFeePercent;


    uint256 private _feeUpdateTimestamp;

    constructor(
		address DevelopmentWallet,
		address MarketingWallet,
		address RewardsWallet,
		address LiquidityWallet
    ) ERC20("Pizza", "PZA") {
        _mint(_msgSender(), 1000);

		_transactionFeePercent = 15e16; // 15%


		_DevelopmentWallet = DevelopmentWallet;
		_MarketingWallet = MarketingWallet;
		_RewardsWallet = RewardsWallet;
		_LiquidityWallet = LiquidityWallet;


		_DevelopmentWalletFeePercent = 25e16; //25%
		_MarketingWalletFeePercent = 25e16; //25%
		_RewardsWalletFeePercent = 25e16; //25%
		_LiquidityWalletFeePercent = 25e16; //25%


        // initialize timelock conditions
        currentTimelocks[Functions.FEE] = 0;
        currentTimelocks[Functions.FEE_OWNER] = 0;
        currentTimelocks[Functions.FEE_DIST] = 0;

        hasPendingFee[Functions.FEE] = false;
        hasPendingFee[Functions.FEE_OWNER] = false;
        hasPendingFee[Functions.FEE_DIST] = false;

        //add PZA wallets to whitelistAddresses
        addWhitelistAddress(_msgSender());
		addWhitelistAddress(_DevelopmentWallet);
		addWhitelistAddress(_MarketingWallet);
		addWhitelistAddress(_RewardsWallet);
		addWhitelistAddress(_LiquidityWallet);

    }

    // TODO: Mitigate Contract owner from front-run transfers with fee changes
    // Consider modifing fees with a time lock approach. An initial transaction could specify the new fees,
    // and a subsequent transaction (which must be more than a fixed number of blocks later) can then update the fees.

    // Transfer functions with fee charging
    //

    function transfer(address recipient, uint256 amount)
        public
        override
        updateFees()
        returns (bool)
    {
        _transferWithFee(_msgSender(), recipient, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override updateFees() returns (bool) {
        _transferWithFee(sender, recipient, amount);

        uint256 currentAllowance = allowance(sender, _msgSender());
        require(
            currentAllowance >= amount,
            "BEP20: transfer amount exceeds allowance"
        );
        unchecked {_approve(sender, _msgSender(), currentAllowance - amount);}

        return true;
    }

    function _transferWithFee(
        address sender,
        address recipient,
        uint256 amount
    ) private {
        uint256 feeToCharge;
        //check whitelist first
            if (whitelistAddresses[sender] || whitelistAddresses[recipient]) {
                feeToCharge = amount.mul(_transactionFeePercentOwner).div(1e18);
            } else {
                feeToCharge = amount.mul(_transactionFeePercent).div(1e18);
            }

            uint256 amountAfterFee = amount.sub(feeToCharge);

            (
				uint256 toDevelopment,
				uint256 toMarketing,
				uint256 toRewards,
				uint256 toLiquidity
            ) = calculateFeeDistribution(feeToCharge);

			_transfer(sender, _DevelopmentWallet, toDevelopment);
			_transfer(sender, _MarketingWallet, toMarketing);
			_transfer(sender, _RewardsWallet, toRewards);
			_transfer(sender, _LiquidityWallet, toLiquidity);
            _transfer(sender, recipient, amountAfterFee);
    }

// Calculate Fee distributions

    function calculateFeeDistribution(uint256 amount)
        private
        view
        returns (
			uint256 toDevelopment,
			uint256 toMarketing,
			uint256 toRewards,
			uint256 toLiquidity
        )
    {
		toDevelopment = amount.mul(_DevelopmentWalletFeePercent).div(1e18);
		toMarketing = amount.mul(_MarketingWalletFeePercent).div(1e18);
		toRewards = amount.mul(_RewardsWalletFeePercent).div(1e18);
		toLiquidity = amount.mul(_LiquidityWalletFeePercent).div(1e18);


    }

    // Note: run this code before transfers (from modifier or function's body)
    modifier updateFees() {
        setTransactionFee();
        setTransactionFeeOwner();
        setFeeDistribution();
        _;
    }

    // Getters for Current Transaction fees / distributions

    function getCurrentTransactionFee() public view returns (uint256) {
        return _transactionFeePercent;
    }

    function getCurrentTransactionFeeOwner() public view returns (uint256) {
        return _transactionFeePercentOwner;
    }

    function getCurrentFeeDistribution()
        public
        view
        returns (
			uint256,
			uint256,
			uint256,
			uint256
        )
    {
        return (
			_DevelopmentWalletFeePercent,
			_MarketingWalletFeePercent,
			_RewardsWalletFeePercent,
			_LiquidityWalletFeePercent
        );
    }

    // Getters for Pending Transaction fees / distributions

    function getPendingTransactionFee() public view returns (uint256) {
        return _pendingTransactionFeePercent;
    }

    function getPendingTransactionFeeOwner() public view returns (uint256) {
        return _pendingTransactionFeePercentOwner;
    }

    function getPendingFeeDistribution()
        public
        view
        returns (
			uint256,
			uint256,
			uint256,
			uint256
        )
    {
        return (
			_pendingDevelopmentWalletFeePercent,
			_pendingMarketingWalletFeePercent,
			_pendingRewardsWalletFeePercent,
			_pendingLiquidityWalletFeePercent
        );
    }

    // Getters for Pending Transaction fees / distributions

    function getPendingTransactionFeeTime() public view returns (uint256) {
        return currentTimelocks[Functions.FEE];
    }

    function getPendingTransactionFeeOwnerTime() public view returns (uint256) {
        return currentTimelocks[Functions.FEE_OWNER];
    }

    function getPendingFeeDistributionTime() public view returns (uint256) {
        return currentTimelocks[Functions.FEE_DIST];
    }

    

    //
    // Administration setter functions
    //

    function proposeTransactionFee(uint256 fee) public onlyOwner {
        require(
            fee >= 0 && fee <= 15e16,
            "PZA: transaction fee should be >= 0 and <= 15%"
        );
        require(
            !hasPendingFee[Functions.FEE],
            "PZA: There is a pending fee change already."
        );
        require(
            currentTimelocks[Functions.FEE] == 0,
            "Current Timelock is already initialized with a value"
        );

        _pendingTransactionFeePercent = fee;

        // intialize timelock conditions
        currentTimelocks[Functions.FEE] = block.timestamp + _TIMELOCK; // resets timelock with future timestamp that it will be unlocked
        hasPendingFee[Functions.FEE] = true;
    }

    function proposeTransactionFeeOwner(uint256 fee) public onlyOwner {
        require(
            fee >= 0 && fee <= 15e16,
            "PZA: sell transaction fee should be >= 0 and <= 15%"
        );
        require(
            !hasPendingFee[Functions.FEE_OWNER],
            "PZA: There is a pending owner fee change already."
        );
        require(
            currentTimelocks[Functions.FEE_OWNER] == 0,
            "Current Timelock is already initialized with a value"
        );

        _pendingTransactionFeePercentOwner = fee;

        // intialize timelock conditions
        currentTimelocks[Functions.FEE_OWNER] = block.timestamp + _TIMELOCK; // resets timelock with future timestamp that it will be unlocked
        hasPendingFee[Functions.FEE_OWNER] = true;
    }

    function proposeFeeDistribution(
			uint256 DevelopmentWalletFeePercent,
			uint256 MarketingWalletFeePercent,
			uint256 RewardsWalletFeePercent,
			uint256 LiquidityWalletFeePercent
    ) public onlyOwner {
        require(
				DevelopmentWalletFeePercent
				.add(MarketingWalletFeePercent)
				.add(RewardsWalletFeePercent)
				.add(LiquidityWalletFeePercent) == 1e18,
            "PZA: The sum of distribuition should be 100%"
        );
        require(
            !hasPendingFee[Functions.FEE_DIST],
            "PZA: There is a pending dsitribution fee change already."
        );
        require(
            currentTimelocks[Functions.FEE_DIST] == 0,
            "Current Timelock is already initialized with a value"
        );
			_pendingDevelopmentWalletFeePercent = _DevelopmentWalletFeePercent;
			_pendingMarketingWalletFeePercent = _MarketingWalletFeePercent;
			_pendingRewardsWalletFeePercent = _RewardsWalletFeePercent;
			_pendingLiquidityWalletFeePercent = _LiquidityWalletFeePercent;

        // intialize timelock conditions
        currentTimelocks[Functions.FEE_DIST] = block.timestamp + _TIMELOCK;
        hasPendingFee[Functions.FEE_DIST] = true;
    }

    function setTransactionFee() private {
        if (
            hasPendingFee[Functions.FEE] == true &&
            currentTimelocks[Functions.FEE] <= block.timestamp
        ) {
            _transactionFeePercent = _pendingTransactionFeePercent;

            // reset timelock conditions
            currentTimelocks[Functions.FEE] = 0;
            hasPendingFee[Functions.FEE] = false;
        }
    }

    function setTransactionFeeOwner() private {
        if (
            hasPendingFee[Functions.FEE_OWNER] == true &&
            currentTimelocks[Functions.FEE_OWNER] <= block.timestamp
        ) {
            _transactionFeePercentOwner = _pendingTransactionFeePercentOwner;

            // reset timelock conditions
            currentTimelocks[Functions.FEE_OWNER] = 0;
            hasPendingFee[Functions.FEE_OWNER] = false;
        }
    }

    function setFeeDistribution() private {
        if (
            hasPendingFee[Functions.FEE_DIST] == true &&
            currentTimelocks[Functions.FEE_DIST] <= block.timestamp
        ) {
			_DevelopmentWalletFeePercent = _pendingDevelopmentWalletFeePercent;
			_MarketingWalletFeePercent = _pendingMarketingWalletFeePercent;
			_RewardsWalletFeePercent = _pendingRewardsWalletFeePercent;
			_LiquidityWalletFeePercent = _pendingLiquidityWalletFeePercent;

            // reset timelock conditions
            currentTimelocks[Functions.FEE_DIST] = 0;
            hasPendingFee[Functions.FEE_DIST] = false;
        }
    }

	function setDevelopmentWalletAddress(address DevelopmentAddress) public onlyOwner {
	require(
		DevelopmentAddress != address(0),
		"PZA: DevelopmentAddress cannot be zero address"
	);
	_DevelopmentWallet = DevelopmentAddress;
}
	function setMarketingWalletAddress(address MarketingAddress) public onlyOwner {
	require(
		MarketingAddress != address(0),
		"PZA: MarketingAddress cannot be zero address"
	);
	_MarketingWallet = MarketingAddress;
}
	function setRewardsWalletAddress(address RewardsAddress) public onlyOwner {
	require(
		RewardsAddress != address(0),
		"PZA: RewardsAddress cannot be zero address"
	);
	_RewardsWallet = RewardsAddress;
}
	function setLiquidityWalletAddress(address LiquidityAddress) public onlyOwner {
	require(
		LiquidityAddress != address(0),
		"PZA: LiquidityAddress cannot be zero address"
	);
	_LiquidityWallet = LiquidityAddress;
}

    function addWhitelistAddress(address companyAddress) public onlyOwner {
        whitelistAddresses[companyAddress] = true;
    }

    function removeWhitelistAddress(address companyAddress) public onlyOwner {
        require(
            whitelistAddresses[companyAddress] == true,
            "The company address you're trying to remove does not exist or already has been removed"
        );
        whitelistAddresses[companyAddress] = false;
    }




}
