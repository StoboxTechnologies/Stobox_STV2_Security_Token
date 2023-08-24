// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Utils.sol";

abstract contract Whitelist is Utils {
    /// @notice flag true - whitelist turned on, otherwise - turn off
    bool public _isEnabledWhitelist;

    /// @notice Event emitted when `creator` whitelists `_account`
    event Whitelisted(address creator, address indexed _account);

    /// @notice Event emitted when 'creator' removes `_account` from whitelist
    event DeWhitelisted(address creator, address indexed _account);

    constructor(bool isEnabledWhitelist_) {
        _isEnabledWhitelist = isEnabledWhitelist_;
    }

    /// @notice Toggle of checking whitelist, turns it on or off
    /// @dev Allowed only for SuperAdmin.
    ///      When `_isEnabledWhitelist` false, all whitelisted addresses do not lose status true-whitelisted,
    ///      but contract just doesn't check if the address whitelisted.
    /// @param _value set `true`, if you want to turn on checking of whitelist, otherwise - set `false`
    function toggleWhitelist(bool _value) external onlySuperAdmin {
        _isEnabledWhitelist = _value;
    }

    /// @notice Adds array of addresses (`_bundleAddresses`) to whitelist
    /// @dev Allowed only for ComplianceManager.
    ///      Function blocked when contract is paused.
    ///      Emits event {Whitelisted} for all addresses of array
    /// @param _bundleAddresses array of addresses to add to whitelist
    function addAddressToWhitelist(
        address[] calldata _bundleAddresses
    ) external ifTokenNotPaused onlyComplianceManager {
        _checkArray(_bundleAddresses);
        for (uint256 i = 0; i < _bundleAddresses.length; i++) {
            address ad = _bundleAddresses[i];
            _addAddressToWhitelist(ad);
        }
    }

    /// @notice Removes array of addresses (`_bundleAddresses`) from whitelist
    /// @dev Allowed only for ComplianceManager.
    ///      Function blocked when contract is paused.
    ///      Emits event {DeWhitelisted} for all addresses of array
    /// @param _bundleAddresses array of addresses to remove from whitelist
    function removeAddressFromWhitelist(
        address[] calldata _bundleAddresses
    ) external ifTokenNotPaused onlyComplianceManager {
        _checkArray(_bundleAddresses);
        for (uint256 i = 0; i < _bundleAddresses.length; i++) {
            address ad = _bundleAddresses[i];
            _removeAddressFromWhitelist(ad);
        }
    }

    /// @notice Checks is `_address` whitelisted
    /// @return true if `_address` whitelisted and false, if not
    function isWhitelistedAddress(
        address _address
    ) external view returns (bool) {
        return userData[_address].whitelisted;
    }

    /// @dev Whitelists the `_address`:
    ///      - adds the address to the {PersonalInfo.userAddress}
    ///      - sets the value `true` for {PersonalInfo.whitelisted}
    ///      Emits {Whitelisted} event.
    function _addAddressToWhitelist(address _address) internal {
        userData[_address].userAddress = _address;
        userData[_address].whitelisted = true;
        emit Whitelisted(_msgSender(), _address);
    }

    /// @dev Dewhitelists the `_address`:
    ///      - sets the value `false` for {PersonalInfo.whitelisted}
    ///      Emits {DeWhitelisted} event.
    function _removeAddressFromWhitelist(address _address) internal {
        userData[_address].whitelisted = false;
        emit DeWhitelisted(_msgSender(), _address);
    }
}
