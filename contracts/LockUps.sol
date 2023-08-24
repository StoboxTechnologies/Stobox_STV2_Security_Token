// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Utils.sol";

abstract contract LockUps is Utils {
    /// @notice flag true - LockUps turned on, otherwise - turn off
    bool public _isEnabledLockUps;

    /// @notice Event emited when 'creator' locks `lockedAmount` of tokens
    /// on the address of `tokensOwner` until `timestampToUnlock` will come
    event LockTokens(
        address creator,
        address tokensOwner,
        uint256 timestampToUnlock,
        uint256 lockedAmount
    );

    /// @notice Event emited when locked tokens unlock
    event UnlockTokens(
        address tokensOwner,
        uint256 timestampWhenUnlocked,
        uint256 unlockedAmount
    );

    constructor(bool isEnabledLockUps_) {
        _isEnabledLockUps = isEnabledLockUps_;
    }

    /// @notice Toggle of checking lockUps, turns it on or off
    /// @dev Allowed only for SuperAdmin.
    ///      When `isEnabledLockUps_` false, all information abount locked tokens stay and will not be deleted,
    ///      but contract just doesn't check if the address has locked tokens.
    ///      If `isEnabledLockUps_` will become true again - locked tokens will be unavailable again
    /// @param _value set `true`, if you want to turn on checking of lockUps, otherwise - set `false`
    function toggleLockUps(bool _value) external onlySuperAdmin {
        _isEnabledLockUps = _value;
    }

    /// @notice Transfers amount of tokens from array `_bundleAmounts` from {_corporateTreasury}
    ///         to addresses from array of addresses `_bundleTo`
    ///         and at one time locks these tokens for the `_daysToLock` quantity of days
    /// @dev Allowed only for FinancialManager.
    ///      Function blocked when contract is paused.
    ///      To be able to call this function FinancialManager has
    ///      to be given unlimited {approve} from {_corporateTreasury}
    ///      The proper pair of data: (timestamp when tokens can be unlocked & proper
    ///      amount from `_bundleAmounts`) is written to
    ///      the parametr of account: {personalLockUps} for each account from the array
    ///      Address => value transferred and locked according to indexes of arrays:
    ///      to [0]indexed address will be transferred and locked [0]indexed amount of tokens,
    ///      to [1]indexed address will be transferred and locked [1]indexed amount of tokens and so on
    /// @param _bundleTo array of addresses which will receive tokens and on which they will be locked
    /// @param _bundleAmounts array of amounts of tokens to transfer & lock
    /// @param _daysToLock the quantity of days you want to lock tokens for
    /// @return true if function passed successfully
    function transferFromTreasuryLockedTokens(
        address[] memory _bundleTo,
        uint256[] memory _bundleAmounts,
        uint256 _daysToLock
    ) external ifTokenNotPaused onlyFinancialManager returns (bool) {
        require(_isEnabledLockUps, "STV2: LockUps switched off");

        _equalArrays(_bundleTo, _bundleAmounts);
        for (uint256 i = 0; i < _bundleTo.length; i++) {
            _lockAndTransfer(
                corporateTreasury(),
                _bundleTo[i],
                _bundleAmounts[i],
                _daysToLock
            );
        }
        return true;
    }

    /// @notice Locks amount of tokens from `_bundleAmounts` on account from the array of
    ///         addresses `_bundleTo` for the `_daysToLock` quantity of days
    /// @dev Allowed only for FinancialManager.
    ///      Function blocked when contract is paused.
    ///      The proper pair of data: ([0]timestamp when tokens can be unlocked & [1]locked amount of token)
    ///      is written to the parametr of account: {personalLockUps} for each account from the array
    ///      Function checks the opportunity to lock `_amountToLock`=> see
    ///      comments to function {_checkAmountToLock} to know how is it checked.
    ///      And lock amount from `_bundleAmounts` of tokens or the
    ///      whole available balance of account from `_bundleTo`.
    ///      Address => value locked according to indexes of arrays:
    ///      on [0]indexed address will be locked [0]indexed amount of tokens,
    ///      on [1]indexed address will be locked [1]indexed amount of tokens and so on
    /// @param _bundleTo array of addresses on which tokens will be locked
    /// @param _bundleAmounts array of amounts of tokens to lock
    /// @param _daysToLock the quantity of days you want to lock tokens for
    /// @return true if function passed successfully
    function lockUpTokensOnAddress(
        address[] memory _bundleTo,
        uint256[] memory _bundleAmounts,
        uint256 _daysToLock
    ) external ifTokenNotPaused onlyFinancialManager returns (bool) {
        require(_isEnabledLockUps, "STV2: LockUps switched off");

        _equalArrays(_bundleTo, _bundleAmounts);
        for (uint256 i = 0; i < _bundleTo.length; i++) {
            _lockTokens(
                _bundleTo[i],
                _checkAmountToLock(_bundleTo[i], _bundleAmounts[i]),
                _daysToLock
            );
        }
        return true;
    }

    /// @notice Returns the array of pairs of locked tokens and their timestamps to
    ///         be unlocked for the `_account`
    /// @dev Array of arrays of 2 elements([0]:timestamp, [1]:blocked amount)
    function getListOfLockUps(
        address _account
    ) public view returns (uint256[2][] memory) {
        return userData[_account].personalLockUps;
    }

    /// @notice Returns the whole value of all locked tokens on the `_account`
    ///         if toggle `_isEnabledLockUps` is false - returns 0
    /// @dev Function gets the list of all LockUps on the `_account` (see {getListOfLockUps}),
    ///      loops through the pairs, checks whether the
    ///      required timestamp has not yet arrived and if not - adds the amounts
    /// @param _account address to find out locked amount of tokens
    /// @return (the) sum of amounts of locked tokens of all lockUps on this address
    function getAmountOfLockedTokens(
        address _account
    ) public view returns (uint256) {
        uint256 result = 0;

        if (!(_isEnabledLockUps)) {
            return result;
        } else {
            uint256[2][] memory lockUps = getListOfLockUps(_account);
            uint256 len = lockUps.length;

            if (len == 0) {
                return result;
            } else {
                for (uint256 i = 0; i < len; i++) {
                    if (lockUps[i][0] >= block.timestamp) {
                        result += lockUps[i][1];
                    }
                }
                return result;
            }
        }
    }

    /// @notice Updates the lockUps of the `_account` according to timestamps.
    ///         If the time to unlock certain amount of tokens has come,
    ///         it makes these tokens "free".
    /// @dev Function loops through the array of pairs with data about locked tokens:
    ///      {PersonalInfo.personalLockUps}
    ///      If the [0]indexed parametr of pair (timestamp to unlock) is less then current
    ///      timestamp - {block.timestamp} => it will be deleted from the array
    ///      and the [1]indexed amount of tokens will be unlocked in such a way
    ///      and Event {UnlockTokens} emits.
    ///      Otherwise - this pair is passed and tokens stay locked.
    /// @param _account address to update its LockUps
    /// @return true if function passed successfully
    function updateDataOfLockedTokensOf(
        address _account
    ) public returns (bool) {
        if (userData[_account].personalLockUps.length == 0) {
            return true;
        } else {
            uint count = 0;
            uint256[2][] memory memoryArray = new uint256[2][](
                userData[_account].personalLockUps.length
            );
            for (uint256 i = 0; i < memoryArray.length; i++) {
                if (
                    userData[_account].personalLockUps[i][0] <= block.timestamp
                ) {
                    emit UnlockTokens(
                        _account,
                        block.timestamp,
                        userData[_account].personalLockUps[i][1]
                    );
                } else {
                    memoryArray[i] = userData[_account].personalLockUps[i];
                    count++;
                }
            }

            uint256[2][] memory finalArray = new uint256[2][](count);
            uint k = 0;

            for (uint256 i = 0; i < memoryArray.length; i++) {
                if (memoryArray[i][0] > 0) {
                    finalArray[k] = memoryArray[i];
                    k++;
                }
            }

            userData[_account].personalLockUps = finalArray;
            return true;
        }
    }

    /// @notice Returns the address of the official corporate wallet
    function corporateTreasury() public view virtual returns (address);

    /// @dev Returns currently available amount of tokens to use (transfer) by `_account`:
    ///      calculates the difference between the whole balance of tokens and
    ///      locked tokens on the `_account`
    function _availableBalance(
        address _account
    ) internal view virtual returns (uint256);

    /// @dev Checks what amount to lock on `_account`:
    ///      compare {_availableBalance} of `_account` and `_amountToLock`
    ///      and returns the less value.
    ///      This function does not allow to lock tockens which `_account` does not have
    ///      on its balance yet, in other words, to get a "negative balance" for `_account`
    function _checkAmountToLock(
        address _account,
        uint256 _amountToLock
    ) internal view returns (uint256 resultedAmount) {
        _availableBalance(_account) > _amountToLock
            ? resultedAmount = _amountToLock
            : resultedAmount = _availableBalance(_account);
    }

    /// @dev locks `_amount` of tokens on `_account` for `_daysToLock` quantity of days:
    ///      Adds the pair ([0]timestemp when tokens can be unlocked, [1] `_amount`) to the
    ///      array {PersonalInfo.personalLockUps}
    ///      Emits {LockTokens} event.
    function _lockTokens(
        address _account,
        uint256 _amount,
        uint256 _daysToLock
    ) internal {
        uint256[2] memory lockedPair;
        // Calculates the timstamp, when tokens can be unlocked:
        // interprets a function parameter in days `_daysToLock`
        // into Unix Timestamp( in seconds since JAN 01 1970)
        lockedPair[0] = block.timestamp + (_daysToLock * 1 days);
        lockedPair[1] = _amount;

        userData[_account].personalLockUps.push(lockedPair);
        emit LockTokens(_msgSender(), _account, lockedPair[0], _amount);
    }

    /// @dev Helping function for {transferFromTreasuryLockedTokens}
    ///      to combine two actions: {_lockTokens} & {_transfer}
    function _lockAndTransfer(
        address _from,
        address _to,
        uint256 _amount,
        uint256 _daysToLock
    ) internal virtual;
}
