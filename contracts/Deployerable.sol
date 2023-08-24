// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (a deployer) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the deployer account will be the one that deploys the contract.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyDeployer`, which can be applied to your functions to restrict their use to
 * the deployer.
 */
abstract contract Deployerable is Context {
    address private _deployer;

    event DeployershipTransferred(
        address indexed previousDeployer,
        address indexed newDeployer
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial deployer.
     */
    constructor() {
        _transferDeployership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the deployer.
     */
    modifier onlyDeployer() {
        _checkDeployer();
        _;
    }

    /**
     * @dev Returns the address of the current deployer.
     */
    function deployer() public view returns (address) {
        return _deployer;
    }

    /**
     * @dev Throws if the sender is not the deployer.
     */
    function _checkDeployer() internal view {
        require(
            deployer() == _msgSender(),
            "Deployerable: caller is not deployer"
        );
    }

    /**
     * @dev Leaves the contract without deployer. It will not be possible to call
     * `onlyDeployer` functions anymore. Can only be called by the current deployer.
     *
     * NOTE: Renouncing deployership will leave the contract without an deployer,
     * thereby removing any functionality that is only available to the deployer.
     */
    function renounceDeployership() external onlyDeployer {
        _transferDeployership(address(0));
    }

    /**
     * @dev Transfers deployership of the contract to a new account (`newDeployer`).
     * Can only be called by the current deployer.
     */
    function transferDeployership(address newDeployer) external onlyDeployer {
        require(newDeployer != address(0), "Deployerable: invalid newDeployer");
        _transferDeployership(newDeployer);
    }

    /**
     * @dev Transfers deployership of the contract to a new account (`newDeployer`).
     * Internal function without access restriction.
     */
    function _transferDeployership(address newDeployer) internal {
        address oldDeployer = _deployer;
        _deployer = newDeployer;
        emit DeployershipTransferred(oldDeployer, newDeployer);
    }
}
