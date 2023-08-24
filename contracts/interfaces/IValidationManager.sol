// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IValidationManager {
    event LinkedRule(address indexed rule, uint256 indexed ruleIndex);

    event UnLinkedRule(address indexed rule);

    event ValidationDisabled(address account);

    event ValidationEnabled(address account);

    function linkRule(address _ruleAddress, uint256 _index) external;

    function unlinkRule(address _ruleAddress) external;

    function disableValidation() external;

    function enableValidation() external;

    function getSecurityTokenAddress() external view returns (address);

    function getListOfAllRules() external view returns (address[] memory);

    function validationDisabled() external view returns (bool);

    function validateToTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) external view;

    function validateToInteractSingle(address _account) external view;

    function validateToInteract(address _from, address _to) external view;
}
