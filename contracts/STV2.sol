// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/IValidationManager.sol";
import "./BaseERC20.sol";
import "./Deployerable.sol";
import "./Roles.sol";
import "./Whitelist.sol";
import "./Limits.sol";
import "./LockUps.sol";

/// @title STV2
/// @author Stobox Technologies Inc.
/// @notice Smart Contract of security token. Version 2.0
/// @dev STV2 is ERC20-token with additional restrictions and abilities
contract STV2 is
    Pausable,
    Deployerable,
    Roles,
    Whitelist,
    Limits,
    LockUps,
    BaseERC20
{
    address private _validationManager;

    /// @notice oficial corporate wallet of the Company, to which tokens are minted and then distributed
    address private _corporateTreasury;

    modifier onlyWhitelisted(address _account) override {
        if (_isEnabledWhitelist) {
            require(userData[_account].whitelisted, "STV2: Not whitelisted");
        }
        _;
    }

    modifier ifTokenNotPaused() override {
        _requireNotPaused();
        _;
    }

    modifier onlySuperAdmin() override {
        _checkRole(DEFAULT_ADMIN_ROLE);
        _;
    }

    modifier onlyRecoveryManager() override {
        _checkRole(RECOVERY_MANAGER_ROLE);
        _;
    }

    modifier onlyComplianceManager() override {
        _checkRole(COMPLIANCE_MANAGER_ROLE);
        _;
    }

    modifier onlyFinancialManager() override {
        _checkRole(FINANCIAL_MANAGER_ROLE);
        _;
    }

    /// @dev in constructor, except that the values ​​of important variables will be set,
    /// will be executed next actions:
    /// * whitelisted msg.sender(deployer of the contract),
    /// * whitelisted all addresses which will be granted roles (superAdmin,
    ///   financialManager, complianceOfficer, masterManager)
    /// * corporateTreasury will be whitelisted and it will be assigned maximum
    ///   secondary trading & transaction count limits (2**256 - 1)
    /// * financialManager will be approved to make unlimited transactions from corporateTreasury
    constructor(
        //official corporate wallet, where tokens will be minted
        address corporateTreasury_,
        //list of addresses which will be assigned important roles (see contract {Roles}):
        // * address[0] - superAdmin - will have rights to assign all roles (see contract {Roles})
        // * address[1] - financialManager
        // * address[2] - complianceManager
        // * address[3] - recoveryManager
        address[4] memory _managers,
        //flag determines whether the whitelist is enabled
        bool isEnabledWhitelist_,
        //flag determines whether the whitelist is enabled
        bool isEnabledLockUps_,
        //list of flags determines whether the SecondaryTradingLimit & TransactionCountLimit are enabled.
        //bool-values which will show if the limits have to be switch-ON (see contract {Limits}):
        // * enableLimits[0] - true: the SecondaryTradingLimit will be switchON, false: switchOFF
        // * enableLimits[1] - true: the TransactionCountLimit will be switchON, false: switchOFF
        bool[2] memory _enableLimits,
        //list of values which will be set as default Secondary &
        //Transaction Limits (see contract {Limits}):
        // * defaultLimits[0] - the value of defaultSecondaryTradingLimit_
        // * defaultLimits[1] - the value of defaultTransactionCountLimit_
        uint256[2] memory _defaultLimits,
        //name of token
        string memory name_,
        //symbol of token
        string memory symbol_,
        //value of decimals for token. For security token must be `0`
        uint8 decimals_
    )
        BaseERC20(name_, symbol_, decimals_)
        Roles(_managers)
        Whitelist(isEnabledWhitelist_)
        LockUps(isEnabledLockUps_)
        Limits(corporateTreasury_, _enableLimits, _defaultLimits)
    {
        _corporateTreasury = corporateTreasury_;

        _addAddressToWhitelist(_msgSender());
        _addAddressToWhitelist(_managers[0]);
        _addAddressToWhitelist(_managers[1]);
        _addAddressToWhitelist(_managers[2]);
        _addAddressToWhitelist(_managers[3]);
        _addAddressToWhitelist(corporateTreasury_);
    }

    /// @notice Pauses all functions of contract which have modifier `whenNotPaused`
    /// @dev Allowed only for SuperAdmin
    function pauseContract() external onlySuperAdmin {
        _pause();
    }

    /// @notice Unpauses all functions of contract
    /// @dev Allowed only for SuperAdmin
    function unpauseContract() external onlySuperAdmin {
        _unpause();
    }

    /// @notice Set the address of ValidationManager with which validation will be done
    /// @dev Allowed only for Deployer (see contract Deployerable)
    function setValidationManager(
        address _validationAddress
    ) external onlyDeployer {
        _validationManager = _validationAddress;
    }

    /// @notice Moves the the corporate official wallet to another
    ///         address with all necessary changes such as:
    ///         moving the whole balance of tokens, setting proper limits for old and new treasuries
    ///         giving rights fo Financial Manager(s) to use new corporate wallet.
    /// @dev Allowed only for SuperAdmin.
    ///      `_newTreasury` can not be zero-address
    /// @param _newTreasury new address of the wallet to set.
    function replacementOfCorporateTreasury(
        address _newTreasury
    ) external onlySuperAdmin {
        require(_newTreasury != address(0), "STV2:Treasury can not be zero");

        address oldTreasury = corporateTreasury();
        uint256 oldTreasuryBalance = balanceOf(oldTreasury);
        uint256 newTreasuryBalance = balanceOf(_newTreasury);

        //whitelisting of the address of new Treasury
        _addAddressToWhitelist(_newTreasury);

        //moves the whole balance of tokens from old Treasury to the new one
        _transfer(oldTreasury, _newTreasury, oldTreasuryBalance);

        //checks if the balance of tokens was successfully moved
        require(
            balanceOf(oldTreasury) == 0 &&
                balanceOf(_newTreasury) ==
                newTreasuryBalance + oldTreasuryBalance,
            "STV2: balance of Treasury was not replaced"
        );

        //resets the limits(secondary trading and transction count) of
        //old Treasury to the default values
        userData[oldTreasury].hasOwnSecondaryLimit = false;
        userData[oldTreasury].hasOwnTransactionCountLimit = false;

        //sets the address of new Treasury as the proper parameter of smart contract
        _corporateTreasury = _newTreasury;

        //sets the maximum limits for the new Treasury (2**256-1)
        _setSecondaryTradingLimitFor(_newTreasury, MAX_UINT);
        _setTransactionCountLimitFor(_newTreasury, MAX_UINT);

        //removing of the address of old Treasury from whitelist
        _removeAddressFromWhitelist(oldTreasury);
    }

    /// @notice Burns amounts of tokens from the array `_bundleAmounts`
    ///         from the addresses of the array of addresses `_bundleFrom`
    /// @dev Allowed only for RecoveryManager
    ///      Address => value burnt according to indexes of arrays:
    ///      from [0]indexed address will be burnt [0]indexed amount of tokens,
    ///      from [1]indexed address will be burnt [1]indexed amount of tokens and so on
    /// @param _bundleFrom array of addresses to burn tokens from
    /// @param _bundleAmounts array of amounts of tokens to burn
    function burnBundle(
        address[] memory _bundleFrom,
        uint256[] memory _bundleAmounts
    ) external onlyRecoveryManager {
        _bundlesLoop(_bundleFrom, _bundleAmounts, _burn);
    }

    /// @notice Burns whole balance of tokens from all addresses of the array of addresses `_bundleFrom`
    /// @dev Allowed only for RecoveryManager
    /// @param _bundleFrom array of addresses to burn tokens from
    function redemption(
        address[] memory _bundleFrom
    ) external onlyRecoveryManager returns (bool) {
        for (uint256 i = 0; i < _bundleFrom.length; i++) {
            uint256 amountToBurn = balanceOf(_bundleFrom[i]);
            _burn(_bundleFrom[i], amountToBurn);
        }
        return true;
    }

    /// @notice This function can release ERC20-tokens `_tokensToWithdraw`, which
    ///         got stuck in this smart contract (were transferred here by the mistake)
    /// @dev Allowed only for SuperAdmin.
    ///      Transfers all balance of stuck `_tokensToWithdraw` from
    ///      this contract to {_corporateTreasury} wallet
    /// @param _tokensToWithdraw address of ERC20-token to withdraw
    function withdrawStuckTokens(
        address _tokensToWithdraw
    ) external onlySuperAdmin {
        address from = address(this);
        uint256 amount = IERC20(_tokensToWithdraw).balanceOf(from);
        IERC20(_tokensToWithdraw).transfer(_corporateTreasury, amount);
    }

    /// @notice Transfers amounts from array `_bundleAmounts` of tokens from {_corporateTreasury}
    ///          to all addresses from array of addresses `_bundleTo`
    /// @dev Allowed only for FinancialManager.
    ///      Function blocked when contract is paused.
    ///      To be able to call this function FinancialManager has
    ///      to be given unlimited {approve} from {_corporateTreasury}
    ///      Address => value are transferred according to indexes of arrays:
    ///      [0]indexed amount of tokens will be transferred to [0]indexed address,
    ///      [1]indexed amount of tokens will be transferred to [1]indexed address and so on
    /// @param _bundleTo array of addresses which will receive tokens
    /// @param _bundleAmounts array of amounts of tokens to transfer
    /// @return true if function passed successfully
    function transferFromTreasuryToInvestor(
        address[] memory _bundleTo,
        uint256[] memory _bundleAmounts
    ) external whenNotPaused onlyFinancialManager returns (bool) {
        _bundlesLoop(_corporateTreasury, _bundleTo, _bundleAmounts, _transfer);
        return true;
    }

    /// @notice Returns the personal data of `_account`
    ///         returns the array with next data of this account:
    /// *userAddress,
    /// *whole user Balance of tokens,
    /// *amount of Locked tokens of user,
    /// *is address whitelisted(true/false),
    /// *left Secondary Limit for account (user can spend yet),
    /// *SecondaryLimit which is set for this account,
    /// *left Transaction Limit for account (user can spend yet),
    /// *TransactionCountLimit which is set for this account,
    /// *outputAmount of tokens,
    /// *transactionCount of transfers,
    /// *personalLockUps - array of arrays of 2 elements([0]:timestamp, [1]:blocked amount)
    function getUserData(
        address _account
    ) external view returns (ActualUserInfo memory) {
        ActualUserInfo memory actualInfo;
        actualInfo = ActualUserInfo(
            _account,
            balanceOf(_account),
            getAmountOfLockedTokens(_account),
            userData[_account].whitelisted,
            getAllowedToTransfer(_account),
            secondaryTradingLimitOf(_account),
            getLeftTransactionCountLimit(_account),
            transactionCountLimitOf(_account),
            userData[_account].outputAmount,
            userData[_account].transactionCount,
            userData[_account].personalLockUps
        );

        return actualInfo;
    }

    /// @notice Returns the address of the official corporate wallet
    function corporateTreasury() public view override returns (address) {
        return _corporateTreasury;
    }

    /// @notice Returns the address of the current ValidationManager smart contract
    function getValidationManager() public view returns (address) {
        return _validationManager;
    }

    /// @notice Returns the value of amount of tokens which `_account`
    ///         can spend(transfer) this moment
    /// @dev Function takes two numbers: {_availableBalance} & {_availableLimit}
    ///      and compaire them.
    ///      {_availableBalance} - subtracts from the total balance value of lockUps
    ///      {_availableLimit} - returns currently available limit for this address
    ///      Then returns the smaller value.
    function getAllowedToTransfer(
        address _account
    ) public view returns (uint256 result) {
        _availableBalance(_account) < _availableLimit(_account)
            ? result = _availableBalance(_account)
            : result = _availableLimit(_account);
    }

    /// @notice Moves `_amount` of tokens from the array of amounts `_bundleAmounts` from
    ///         the caller's account to each address
    ///         from array of  addresses `_bundleTo`.
    /// @dev Emits a {Transfer} event for each transfer of this multi-sending function.
    ///      Function blocked when contract is paused.
    ///      Function has a number of checks and conditions - see {_transfer} internal function.
    ///      Address => value transferred according to indexes of arrays:
    ///      to [0]indexed address will be sent [0]indexed amount of tokens,
    ///      to [1]indexed address will be sent [1]indexed amount of tokens and so on
    /// @param _bundleTo array of addresses which will get tokens
    /// @param _bundleAmounts array of amounts to transfer
    /// @return true if function passed successfully
    function transferBundle(
        address[] memory _bundleTo,
        uint256[] memory _bundleAmounts
    ) public whenNotPaused returns (bool) {
        address owner = _msgSender();
        _bundlesLoop(owner, _bundleTo, _bundleAmounts, _transfer);
        return true;
    }

    /// @dev This hook is called before any transfer of tokens(except minting & burning).
    ///      Increases the {PersonalInfo.outputAmount} of `_from` account by `_amount`
    ///      Increases the counter of transactions of `_from` account
    ///      by 1 ({PersonalInfo.transactionCount})
    ///      Requirements:
    ///      *available Transaction Count Limit of `_from` has to be > 0
    ///      *{_availableLimit} of `_from` account cannot be less then `_amount` to transfer
    ///      *{_availableBalance} of `_from` account cannot be less then `_amount` to transfer
    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal override {
        require(
            getLeftTransactionCountLimit(_from) > 0,
            "STV2: Has no TransactionCountLimit"
        );

        require(
            _availableLimit(_from) >= _amount,
            "STV2: Not enough SecondaryTradingLimit"
        );

        require(
            _availableBalance(_from) >= _amount,
            "STV2: Not enough balance or you transfer locked tokens"
        );

        _validateToInteract(_from, _to);
        _validateToTransfer(_from, _to, _amount);

        userData[_from].outputAmount += _amount;
        userData[_from].transactionCount++;
    }

    /// @dev This hook is called after any transfer of tokens(except minting & burning).
    ///      Updates(actualize) PersonalInfo.personalLockUps of `_from`
    ///      account => see {updateDataOfLockedTokensOf}
    function _afterTokenTransfer(address _from) internal override {
        updateDataOfLockedTokensOf(_from);
    }

    /// @dev Makes validation of the single address
    ///     If ValidationManager address was not set (= address(0)), validation is skipped
    function _validateToInteractSingle(
        address _account
    ) internal view override(BaseERC20, Roles) {
        if (_validationManager != address(0)) {
            IValidationManager(_validationManager).validateToInteractSingle(
                _account
            );
        }
    }

    /// @dev Makes validation if the method has to validste two addresses.
    ///     If ValidationManager address was not set (= address(0)), validation is skipped
    function _validateToInteract(address _from, address _to) internal view {
        if (_validationManager != address(0)) {
            IValidationManager(_validationManager).validateToInteract(
                _from,
                _to
            );
        }
    }

    /// @dev Makes transfer-validation, which has different rules than _validateToInteract
    ///     If ValidationManager address was not set (= address(0)), validation is skipped
    function _validateToTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal view {
        if (_validationManager != address(0)) {
            IValidationManager(_validationManager).validateToTransfer(
                _from,
                _to,
                _amount
            );
        }
    }

    /// @dev Returns currently available amount of tokens to use (transfer) by `_account`:
    ///      calculates the difference between the whole balance of tokens and
    ///      locked tokens on the `_account`
    function _availableBalance(
        address _account
    ) internal view override returns (uint256) {
        return balanceOf(_account) - getAmountOfLockedTokens(_account);
    }

    /// @dev Helping function for {transferFromTreasuryLockedTokens}
    ///      to combine two actions: {_lockTokens} & {_transfer}
    function _lockAndTransfer(
        address _from,
        address _to,
        uint256 _amount,
        uint256 _daysToLock
    ) internal override {
        _lockTokens(_to, _amount, _daysToLock);
        _transfer(_from, _to, _amount);
    }
}
