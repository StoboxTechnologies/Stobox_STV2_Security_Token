// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Utils.sol";

contract Limits is Utils {
    /// @notice flag true - Secondary limit turned on, otherwise - turn off
    bool public _isEnabledSecondaryTradingLimit;

    /// @notice flag true - Transaction count limit turned on, otherwise - turn off
    bool public _isEnabledTransactionCountLimit;

    /// @notice secondary trading limit which is used for every address without individual limit
    /// (when flag `_isEnabledSecondaryTradingLimit` is true)
    uint256 internal _defaultSecondaryTradingLimit;

    /// @notice transaction count limit which is used for every address without individual limit
    /// (when flag `_isEnabledTransactionCountLimit` is true)
    uint256 internal _defaultTransactionCountLimit;

    /// @notice integer = 2**256 - 1
    uint256 internal MAX_UINT = type(uint256).max;

    constructor(
        address corporateTreasury_,
        bool[2] memory _enableLimits,
        uint256[2] memory _defaultLimits
    ) {
        _isEnabledSecondaryTradingLimit = _enableLimits[0];
        _isEnabledTransactionCountLimit = _enableLimits[1];
        _defaultSecondaryTradingLimit = _defaultLimits[0];
        _defaultTransactionCountLimit = _defaultLimits[1];

        _setSecondaryTradingLimitFor(corporateTreasury_, MAX_UINT);
        _setTransactionCountLimitFor(corporateTreasury_, MAX_UINT);
    }

    /// @notice Toggle of checking TransactionCount limit, turns it on or off
    /// @dev Allowed only for SuperAdmin.
    ///      When `_isEnabledTransactionCountLimit` false, all values
    ///      of limits(default limit or individual limits of addresses) stay saved,
    ///      but contract just doesn't check TransactionCount limit at all.
    /// @param _value set `true`, if you want to turn on checking of limit, otherwise - set `false`
    function toggleTransactionCount(bool _value) external onlySuperAdmin {
        _isEnabledTransactionCountLimit = _value;
    }

    /// @notice Toggle of checking SecondaryTrading limit, turns it on or off
    /// @dev Allowed only for SuperAdmin.
    ///      When `_isEnabledSecondaryTradingLimit` false, all values
    ///      of limits(default limit or individual limits of addresses) stay saved,
    ///      but contract just doesn't check SecondaryTrading limit at all.
    /// @param _value set `true`, if you want to turn on checking of limit, otherwise - set `false`
    function toggleSecondaryTradingLimit(bool _value) external onlySuperAdmin {
        _isEnabledSecondaryTradingLimit = _value;
    }

    /// @notice Sets the value of `_defaultSecondaryTradingLimit`.
    /// @dev Allowed only for ComplianceManager.
    ///      Function blocked when contract is paused.
    /// @param _newLimit the value of limit to set
    function setDefaultSecondaryTradingLimit(
        uint256 _newLimit
    ) external ifTokenNotPaused onlyComplianceManager {
        _defaultSecondaryTradingLimit = _newLimit;
    }

    /// @notice Sets the value of `_defaultTransactionCountLimit`.
    /// @dev Allowed only for ComplianceManager.
    ///      Function blocked when contract is paused.
    /// @param _newLimit the value of limit to set
    function setDefaultTransactionCountLimit(
        uint256 _newLimit
    ) external ifTokenNotPaused onlyComplianceManager {
        _defaultTransactionCountLimit = _newLimit;
    }

    /// @notice Sets the value of `individualSecondaryTradingLimit` for
    ///         each address from array of addresses `_bundleAccounts` as
    ///         the value from array of numbers `_bundleNewLimits`
    /// @dev Allowed only for ComplianceManager.
    ///      Function blocked when contract is paused.
    ///      Address => value set according to indexes of arrays:
    ///      [0]indexed address will have [0]indexed value of limit,
    ///      [1]indexed address will have [1]indexed value of limit and so on
    /// @param _bundleAccounts array of addresses to set new `individualSecondaryTradingLimit`
    /// @param _bundleNewLimits array of the values of limit to set.
    function setSecondaryTradingLimitFor(
        address[] calldata _bundleAccounts,
        uint256[] calldata _bundleNewLimits
    ) external ifTokenNotPaused onlyComplianceManager {
        _bundlesLoop(
            _bundleAccounts,
            _bundleNewLimits,
            _setSecondaryTradingLimitFor
        );
    }

    /// @notice Sets the value of `individualTransactionCountLimit` for
    ///         each address from array of addresses `_bundleAccounts` as
    ///         the value from array of numbers `_bundleNewLimits`
    /// @dev Allowed only for ComplianceManager.
    ///      Function blocked when contract is paused.
    ///      Address => value set according to indexes of arrays:
    ///      [0]indexed address will have [0]indexed value of limit,
    ///      [1]indexed address will have [1]indexed value of limit and so on
    /// @param _bundleAccounts array of addresses to set new `individualTransactionCountLimit`
    /// @param _bundleNewLimits array of the values of limit to set.
    function setTransactionCountLimitFor(
        address[] calldata _bundleAccounts,
        uint256[] calldata _bundleNewLimits
    ) external ifTokenNotPaused onlyComplianceManager {
        _bundlesLoop(
            _bundleAccounts,
            _bundleNewLimits,
            _setTransactionCountLimitFor
        );
    }

    /// @notice After calling this function the {_defaultSecondaryTradingLimit}
    ///         will apply to addresses from array `_accountsToReset`
    ///         instead of there {individualSecondaryTradingLimit} (if they had it)
    /// @dev Allowed only for ComplianceManager.
    /// @param _accountsToReset array of addresses to reset limit to default
    function resetSecondaryTradingLimitToDefault(
        address[] calldata _accountsToReset
    ) external ifTokenNotPaused onlyComplianceManager {
        _checkArray(_accountsToReset);
        for (uint256 i = 0; i < _accountsToReset.length; i++) {
            userData[_accountsToReset[i]].hasOwnSecondaryLimit = false;
        }
    }

    /// @notice After calling this function the {_defaultSecondaryTradingLimit}
    ///         will apply to addresses from array `_accountsToReset`
    ///         instead of there {individualTransactionCountLimit} (if they had it)
    /// @dev Allowed only for ComplianceManager.
    ///      Function blocked when contract is paused.
    ///      Function just changes flag {hasOwnTransactionCountLimit} to `false`
    ///      for the addresses from `_accountsToReset`
    ///      and contract will ignore value which is set in
    ///      the parametr {individualTransactionCountLimit} for each account from array
    /// @param _accountsToReset array of addresses to reset limit to default
    function resetTransactionCountLimitToDefault(
        address[] calldata _accountsToReset
    ) external ifTokenNotPaused onlyComplianceManager {
        _checkArray(_accountsToReset);
        for (uint256 i = 0; i < _accountsToReset.length; i++) {
            userData[_accountsToReset[i]].hasOwnTransactionCountLimit = false;
        }
    }

    /// @notice Returns the value of the default Secondary Trading limit
    function defaultSecondaryTradingLimit() external view returns (uint256) {
        return _defaultSecondaryTradingLimit;
    }

    /// @notice Returns the value of the default Transaction Count limit
    function defaultTransactionCountLimit() external view returns (uint256) {
        return _defaultTransactionCountLimit;
    }

    /// @notice Returns the available number of transfers `_account` can do yet
    /// @dev The function gets two values:
    ///      {transactionCountLimitOf} - the current limit of transfers for the `_account`
    ///      {PersonalInfo.transactionCount} - the number of transfers which `_account` already has made.
    ///      Function returns the substraction: (current limit - made transfers) or revert
    ///      with proper message, if the `_account` doesn't have avalaible limit.
    /// @param _account address to find out its limit
    function getLeftTransactionCountLimit(
        address _account
    ) public view returns (uint256) {
        uint256 limit = transactionCountLimitOf(_account);
        if (userData[_account].transactionCount >= limit) {
            return 0;
        }

        return limit - userData[_account].transactionCount;
    }

    /// @notice Returns the value of the Secondary Trading limit that applies to this '_account'
    /// @dev The function makes several steps of verification:
    ///      * Checks if the control of Secondary Limits turned on:
    ///        the flag {_isEnabledSecondaryTradingLimit}
    ///        is false - returns {MAX_UINT}
    ///        is true:
    ///
    ///          * Checks if the `_account` {hasOwnSecondaryLimit}:
    ///            if true - returns PersonalInfo.individualSecondaryTradingLimit of `_account`
    ///            if false - returns {_defaultSecondaryTradingLimit}
    /// @param _account address to find out the value of its current Secondary Trading limit
    function secondaryTradingLimitOf(
        address _account
    ) public view returns (uint256) {
        if (_isEnabledSecondaryTradingLimit) {
            if (userData[_account].hasOwnSecondaryLimit) {
                return userData[_account].individualSecondaryTradingLimit;
            } else {
                return _defaultSecondaryTradingLimit;
            }
        }
        return MAX_UINT;
    }

    /// @notice Returns the value of the Transaction Count limit that applies to this '_account'
    /// @dev The function makes several steps of verification:
    ///      * Checks if the control of Transaction Count limit turned on:
    ///        the flag {_isEnabledTransactionCountLimit}
    ///        is false - returns {MAX_UINT}
    ///        is true:
    ///
    ///          * Checks if the `_account` {hasOwnTransactionCountLimit}:
    ///            if true - returns PersonalInfo.individualTransactionCountLimit of `_account`
    ///            if false - returns {_defaultTransactionCountLimit}
    /// @param _account address to find out the value of its current Transaction Count limit
    function transactionCountLimitOf(
        address _account
    ) public view returns (uint256) {
        if (_isEnabledTransactionCountLimit) {
            if (userData[_account].hasOwnTransactionCountLimit) {
                return userData[_account].individualTransactionCountLimit;
            } else {
                return _defaultTransactionCountLimit;
            }
        }
        return MAX_UINT;
    }

    /// @dev Sets the `_newLimit` as Individual Secondary Trading Limit for `_account`:
    ///      - sets the value `true` for {PersonalInfo.hasOwnSecondaryLimit}
    ///      - sets the value `_newLimit` for {PersonalInfo.individualSecondaryTradingLimit}
    function _setSecondaryTradingLimitFor(
        address _account,
        uint256 _newLimit
    ) internal {
        userData[_account].hasOwnSecondaryLimit = true;
        userData[_account].individualSecondaryTradingLimit = _newLimit;
    }

    /// @dev Sets the `_newLimit` as Individual Transaction Count Limit for `_account`:
    ///      - sets the value `true` for {PersonalInfo.hasOwnTransactionCountLimit}
    ///      - sets the value `_newLimit` for {PersonalInfo.individualTransactionCountLimit}
    function _setTransactionCountLimitFor(
        address _account,
        uint256 _newLimit
    ) internal {
        userData[_account].hasOwnTransactionCountLimit = true;
        userData[_account].individualTransactionCountLimit = _newLimit;
    }

    /// @dev Returns currently available Secondary Trading limit of `_account`:
    ///      calculates difference between the current limit of `_account` and
    ///      the amount already sent by this address
    function _availableLimit(address _account) internal view returns (uint256) {
        uint256 limit = secondaryTradingLimitOf(_account);
        if (userData[_account].outputAmount >= limit) {
            return 0;
        }
        return limit - userData[_account].outputAmount;
    }
}
