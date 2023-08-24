// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

/// @title Roles
/// @author Stobox Technologies Inc.
/// @notice A contract for assigning and managing roles when interacting with a security token
abstract contract Roles is AccessControlEnumerable {
    bytes32 public constant FINANCIAL_MANAGER_ROLE =
        keccak256("FINANCIAL_MANAGER_ROLE");
    bytes32 public constant COMPLIANCE_MANAGER_ROLE =
        keccak256("COMPLIANCE_MANAGER_ROLE");
    bytes32 public constant RECOVERY_MANAGER_ROLE =
        keccak256("RECOVERY_MANAGER_ROLE");

    constructor(
        //list of addresses which will be assigned important roles (see contract {Roles}):
        // * address[0] - superAdmin
        // * address[1] - financialManager
        // * address[2] - complianceOfficer
        // * address[3] - masterManager
        address[4] memory _managers
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, _managers[0]);
        _grantRole(FINANCIAL_MANAGER_ROLE, _managers[1]);
        _grantRole(COMPLIANCE_MANAGER_ROLE, _managers[2]);
        _grantRole(RECOVERY_MANAGER_ROLE, _managers[3]);
    }

    /// @dev Creates list of addresses with necessary `_role`
    function getListOfRoleOwners(
        bytes32 _role
    ) public view returns (address[] memory) {
        uint256 len = getRoleMemberCount(_role);
        address[] memory resultedList = new address[](len);

        for (uint256 i = 0; i < len; i++) {
            resultedList[i] = getRoleMember(_role, i);
        }
        return resultedList;
    }

    /// @dev Overload {_grantRole} to validate caller and `account` to grant role
    function _grantRole(bytes32 role, address account) internal override {
        _validateToInteractSingle(account);
        super._grantRole(role, account);
    }

    function _revokeRole(bytes32 role, address account) internal override {
        if (role == DEFAULT_ADMIN_ROLE) {
            require(getRoleMemberCount(role) > 1, "Last SuperAdmin");
        }
        super._revokeRole(role, account);
    }

    function _checkRole(bytes32 role) internal view override {
        _validateToInteractSingle(_msgSender());
        super._checkRole(role, _msgSender());
    }

    function _validateToInteractSingle(address _account) internal view virtual;
}
