// SPDX-License-Identifier: MIT




import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "hardhat/console.sol";

contract JON is ERC20, Ownable {
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
	address public _MarketingWallet;
	address public _DeveloperWallet;

    // Percent distribution among wallets and burn
    // Note: The sum of these four values should be 100% (1e18)
	uint256 public _MarketingWalletFeePercent;
	uint256 public _DeveloperWalletFeePercent;
	uint256 public _BurnFeePercent;


    // Proposal Variables
    uint256 private _pendingTransactionFeePercent;
    uint256 private _pendingTransactionFeePercentOwner;


	uint256 public _pendingMarketingWalletFeePercent;
	uint256 public _pendingDeveloperWalletFeePercent;
	uint256 public _pendingBurnFeePercent;


    uint256 private _feeUpdateTimestamp;

    constructor(
		address MarketingWallet,
		address DeveloperWallet
    ) ERC20("Johsssssn", "JON") {
        _mint(_msgSender(), 500000000);

        _transactionFeePercent = 5e16; // 5%
        _transactionFeePercentOwner = 0e16; // 0%


		_MarketingWallet = MarketingWallet;
		_DeveloperWallet = DeveloperWallet;


		_MarketingWalletFeePercent = 50e16; //50%
		_DeveloperWalletFeePercent = 40e16; //40%
		_BurnFeePercent = 10e16; //10%


        // initialize timelock conditions
        currentTimelocks[Functions.FEE] = 0;
        currentTimelocks[Functions.FEE_OWNER] = 0;
        currentTimelocks[Functions.FEE_DIST] = 0;

        hasPendingFee[Functions.FEE] = false;
        hasPendingFee[Functions.FEE_OWNER] = false;
        hasPendingFee[Functions.FEE_DIST] = false;

        //add JON wallets to whitelistAddresses
        addWhitelistAddress(_msgSender());
        addWhitelistAddress(0x000000000000000000000000000000000000dEaD);
		addWhitelistAddress(_MarketingWallet);
		addWhitelistAddress(_DeveloperWallet);

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
            "ERC20: transfer amount exceeds allowance"
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
				uint256 toMarketing,
				uint256 toDeveloper,
				uint256 toBurn
            ) = calculateFeeDistribution(feeToCharge);

            _transfer(sender, 0x000000000000000000000000000000000000dEaD, toBurn);
			_transfer(sender, _MarketingWallet, toMarketing);
			_transfer(sender, _DeveloperWallet, toDeveloper);
            _transfer(sender, recipient, amountAfterFee);
    }

// Calculate Fee distributions

    function calculateFeeDistribution(uint256 amount)
        private
        view
        returns (
			uint256 toMarketing,
			uint256 toDeveloper,
			uint256 toBurn
        )
    {
		toMarketing = amount.mul(_MarketingWalletFeePercent).div(1e18);
		toDeveloper = amount.mul(_DeveloperWalletFeePercent).div(1e18);
		toBurn = amount.sub(toMarketing).sub(toDeveloper);

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
			uint256
        )
    {
        return (
			_MarketingWalletFeePercent,
			_DeveloperWalletFeePercent,
			_BurnWalletFeePercent
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
			uint256
        )
    {
        return (
			_pendingMarketingWalletFeePercent,
			_pendingDeveloperWalletFeePercent,
			_pendingBurnWalletFeePercent
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
            fee >= 0 && fee <= 99e16,
            "JON: transaction fee should be >= 0 and <= 99%"
        );
        require(
            !hasPendingFee[Functions.FEE],
            "JON: There is a pending fee change already."
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
            fee >= 0 && fee <= 99e16,
            "JON: sell transaction fee should be >= 0 and <= 99%"
        );
        require(
            !hasPendingFee[Functions.FEE_OWNER],
            "JON: There is a pending owner fee change already."
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
			uint256 MarketingWalletFeePercent,
			uint256 DeveloperWalletFeePercent,
			uint256 BurnWalletFeePercent
    ) public onlyOwner {
        require(
				MarketingWalletFeePercent
				.add(DeveloperWalletFeePercent)
				.add(BurnWalletFeePercent) == 1e18,
            "JON: The sum of distribuition should be 100%"
        );
        require(
            !hasPendingFee[Functions.FEE_DIST],
            "JON: There is a pending dsitribution fee change already."
        );
        require(
            currentTimelocks[Functions.FEE_DIST] == 0,
            "Current Timelock is already initialized with a value"
        );
_pendingMarketingPercent = MarketingPercent;
_pendingDeveloperPercent = DeveloperPercent;
_pendingBurnPercent = BurnPercent;

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
			_MarketingWalletFeePercent = _pendingMarketingWalletFeePercent;
			_DeveloperWalletFeePercent = _pendingDeveloperWalletFeePercent;
			_BurnWalletFeePercent = _pendingBurnFeePercent;

            // reset timelock conditions
            currentTimelocks[Functions.FEE_DIST] = 0;
            hasPendingFee[Functions.FEE_DIST] = false;
        }
    }

	function setMarketingWalletAddress(address MarketingAddress) public onlyOwner {
	require(
		MarketingAddress != address(0),
		"<contract symbol>: MarketingAddress cannot be zero address"
	);
	_MarketingWallet = MarketingAddress;
}
	function setDeveloperWalletAddress(address DeveloperAddress) public onlyOwner {
	require(
		DeveloperAddress != address(0),
		"<contract symbol>: DeveloperAddress cannot be zero address"
	);
	_DeveloperWallet = DeveloperAddress;
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
