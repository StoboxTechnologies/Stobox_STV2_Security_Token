// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";

abstract contract Utils is Context {
    uint256 internal MAX_ARRAY_LENGTH = 256;

    /// @notice Struct that contains all information about address of user.
    struct PersonalInfo {
        //user's wallet, appointed at the moment when user is whitelisted.
        //default value - address(0)
        address userAddress;
        //true - if address is whitelisted, otherwise - false.
        bool whitelisted;
        //true - if address has individual Secondary limit, otherwise - false.
        bool hasOwnSecondaryLimit;
        //true - if address has individual Transaction Count limit, otherwise - false.
        bool hasOwnTransactionCountLimit;
        //value of individual Secondary limit(if exists), default - 0
        uint256 individualSecondaryTradingLimit;
        //value of individual Transaction Count limit(if exists), default - 0
        uint256 individualTransactionCountLimit;
        //the total amount of all tokens ever sent by the user(address)
        uint256 outputAmount;
        //the total number of all transfers ever made by user(address)
        uint256 transactionCount;
        //dynamic array of arrays of 2 elements([0]:timestamp, [1]:blocked amount)
        uint256[2][] personalLockUps;
    }

    /// @dev service struct to get whole necessary data of User in function `getUserData()`
    ///      without this struct contract get the error:
    ///      {CompilerError: Stack too deep. Try compiling with `--via-ir` (cli) or the equivalent
    ///      `viaIR: true` (standard JSON) while enabling the optimizer.
    ///      Otherwise, try removing local variables.}
    struct ActualUserInfo {
        address userAddress;
        uint256 userBalance;
        uint256 userLockedBalance;
        bool isWhitelisted;
        uint256 leftSecondaryLimit;
        uint256 setSecondaryLimit;
        uint256 leftTransactions;
        uint256 setTransactionLimit;
        uint256 outputAmount;
        uint256 transactionCount;
        uint256[2][] lockUps;
    }

    // mapping address of user => to its struct PersonalInfo
    mapping(address => PersonalInfo) userData;

    modifier onlyWhitelisted(address _account) virtual {
        _;
    }

    modifier ifTokenNotPaused() virtual {
        _;
    }

    modifier onlySuperAdmin() virtual {
        _;
    }

    modifier onlyComplianceManager() virtual {
        _;
    }

    modifier onlyFinancialManager() virtual {
        _;
    }

    modifier onlyRecoveryManager() virtual {
        _;
    }

    /// @dev Helpful function to check if the length of array less then `MAX_ARRAY_LENGTH`
    ///      This check is helpful to avoid the dDOS attack to the smart contract
    function _checkArray(address[] memory _array) internal view {
        require(
            _array.length <= MAX_ARRAY_LENGTH,
            "STV2: Too long array for input"
        );
    }

    /// @dev Helpful function to check if the length of input arrays are equal.
    function _equalArrays(
        address[] memory _addresses,
        uint256[] memory _amounts
    ) internal view {
        _checkArray(_addresses);
        require(
            _addresses.length == _amounts.length,
            "STV2: Different quantity of elements in arrays"
        );
    }

    // Helping functions {_bundlesLoop} serves for using for-loops for arrays in
    // many multi-transaction functions of the contract.
    // They contain the logic how should interact with each other
    // inputed parameters to correctly pass through the loop.
    // The value from first array has to match the other value or
    // the values from second array according to the indexes.
    // One of inputed parameters is internal function, which
    // is executed in the loop too.

    function _bundlesLoop(
        address[] memory _bundleAddress,
        uint256[] memory _bundleAmounts,
        function(address, uint256) internal _foo
    ) internal {
        _equalArrays(_bundleAddress, _bundleAmounts);
        for (uint256 i = 0; i < _bundleAddress.length; i++) {
            _foo(_bundleAddress[i], _bundleAmounts[i]);
        }
    }

    function _bundlesLoop(
        address _accountFrom,
        address[] memory _bundleAddress,
        uint256[] memory _bundleAmounts,
        function(address, address, uint256) internal _foo
    ) internal {
        _equalArrays(_bundleAddress, _bundleAmounts);
        for (uint256 i = 0; i < _bundleAddress.length; i++) {
            _foo(_accountFrom, _bundleAddress[i], _bundleAmounts[i]);
        }
    }
}
