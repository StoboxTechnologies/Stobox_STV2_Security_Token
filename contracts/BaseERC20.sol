// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./interfaces/IValidationManager.sol";
import "./Utils.sol";

/// @title BaseERC20
/// @author Stobox Technologies Inc.
/// @notice A contract for implementing of the standard ERC20-token functionality for security token
abstract contract BaseERC20 is IERC20Metadata, Utils {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    /// @notice The number of decimals used to get its user representation.
    ///         For example, if `decimals` equals `2`, a balance of `505` tokens should
    ///         be displayed to a user as `5.05` (`505 / 10 ** 2`).
    ///         Security Token has to have decimals = `0`
    ///         Common ERC20-Tokens usually opt for a value of 18, imitating the
    ///         relationship between Ether and Wei.
    uint8 private _decimals;

    /// @notice Total amount of emited tokens
    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
    }

    /// @notice Mints `_amount` of tokens to the address `_to`
    /// @dev Allowed only for RecoveryManager
    /// @param _to address to mint on it tokens
    /// @param _amount amount of tokens to mint
    function mint(address _to, uint256 _amount) external onlyRecoveryManager {
        _mint(_to, _amount);
    }

    /// @notice Burns `_amount` of tokens from the address `_from`
    /// @dev Allowed only for RecoveryManager
    /// @param _from address to burn tokens from
    /// @param _amount amount of tokens to burn
    function burn(address _from, uint256 _amount) external onlyRecoveryManager {
        _burn(_from, _amount);
    }

    /// @notice Returns the name of the token.
    function name() public view returns (string memory) {
        return _name;
    }

    /// @notice Returns the symbol of the token, usually a shorter version of the name.
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /// @notice Returns the number of decimals of token
    function decimals() public view returns (uint8) {
        return _decimals;
    }

    /// @notice Returns the amount of tokens in existence.
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /// @notice Returns the amount of tokens owned by `_account`.
    function balanceOf(address _account) public view returns (uint256) {
        return _balances[_account];
    }

    /// @notice Moves `_amount` of tokens from the caller's account to `_to` address.
    /// @dev Emits a {Transfer} event.
    ///      Function blocked when contract is paused.
    ///      Function has a number of checks and conditions - see {_transfer} internal function.
    /// @return true if function passed successfully
    function transfer(
        address _to,
        uint256 _amount
    ) public ifTokenNotPaused returns (bool) {
        address owner = _msgSender();
        _transfer(owner, _to, _amount);
        return true;
    }

    /// @dev Returns the remaining number of tokens that `_spender` will be
    ///      allowed to spend on behalf of `_owner` through {transferFrom}. This is
    ///      zero by default.
    ///      This value changes when {approve} or {transferFrom} are called.
    function allowance(
        address _owner,
        address _spender
    ) public view returns (uint256) {
        return _allowances[_owner][_spender];
    }

    /// @notice Sets `_amount` as the allowance of `_spender` over the caller's tokens.
    ///         Returns a boolean value indicating whether the operation succeeded.
    /// @dev IMPORTANT: Beware that changing an allowance with this method brings the risk
    ///      that someone may use both the old and the new allowance by unfortunate
    ///      transaction ordering. One possible solution to mitigate this race
    ///      condition is to first reduce the spender's allowance to 0 and set the
    ///      desired value afterwards.
    ///
    ///      Function blocked when contract is paused.
    ///      Emits an {Approval} event.
    ///      Function has a number of checks and conditions - see {_approve} internal function.
    function approve(
        address _spender,
        uint256 _amount
    ) public ifTokenNotPaused returns (bool) {
        address owner = _msgSender();
        _validateToInteractSingle(owner);
        _approve(owner, _spender, _amount);
        return true;
    }

    /// @notice Moves `_amount` of tokens from `_from` to `_to` using the allowance mechanism.
    ///         `_amount` is then deducted from the caller's allowance.
    ///         Returns a boolean value indicating whether the operation succeeded.
    /// @dev Function blocked when contract is paused.
    ///      Emits a {Transfer} event.
    ///      Function has a number of checks and conditions - see:
    ///      {_transfer} & {_spendAllowance} internal function.
    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) public ifTokenNotPaused returns (bool) {
        address spender = _msgSender();
        _spendAllowance(_from, spender, _amount);
        _transfer(_from, _to, _amount);
        return true;
    }

    /// @notice This function can move `_amount` of tokens from
    ///         any `_from` address to any whitelisted `_to` address
    /// @dev Allowed only for RecoveryManager.
    ///      Addresses `_from` and `_to` can not be zero-addresses.
    /// @param _from address from which tokens will be transfered
    /// @param _to address where tokens will be transfered
    /// @param _amount of tokens to transfer
    function transferFunds(
        address _from,
        address _to,
        uint256 _amount
    ) external onlyRecoveryManager onlyWhitelisted(_to) {
        require(_from != address(0), "STV2: transfer from zero address");
        require(_to != address(0), "STV2: transfer to zero address");

        uint256 fromBalance = _balances[_from];
        require(
            fromBalance >= _amount,
            "STV2: transfer amount exceeds balance"
        );

        _validateToInteractSingle(_to);

        unchecked {
            _balances[_from] = fromBalance - _amount;
            _balances[_to] += _amount;
        }
        emit Transfer(_from, _to, _amount);
    }

    /// @notice Increases the allowance granted to `_spender` by the caller.
    /// @dev This is an alternative to {approve} that can be used as a mitigation for
    ///      problems described in {approve}.
    ///      Function blocked when contract is paused.
    ///      Emits an {Approval} event indicating the updated allowance.
    ///      Function has a number of checks and conditions - see {_approve} internal function.
    ///      Requirements:
    ///      `spender` cannot be the zero address.
    function increaseAllowance(
        address _spender,
        uint256 _addedValue
    ) public ifTokenNotPaused returns (bool) {
        address owner = _msgSender();
        _validateToInteractSingle(owner);
        _approve(owner, _spender, allowance(owner, _spender) + _addedValue);
        return true;
    }

    /// @notice Decreases the allowance granted to `_spender` by the caller.
    /// @dev This is an alternative to {approve} that can be used as a mitigation for
    ///      problems described in {approve}.
    ///      Function blocked when contract is paused.
    ///      Emits an {Approval} event indicating the updated allowance.
    ///      Function has a number of checks and conditions - see {_approve} internal function.
    ///      Requirements:
    ///      `_spender` cannot be the zero address.
    ///      `_spender` must have allowance for the caller of at least `subtractedValue`.
    function decreaseAllowance(
        address _spender,
        uint256 _subtractedValue
    ) public ifTokenNotPaused returns (bool) {
        address owner = _msgSender();
        _validateToInteractSingle(owner);
        uint256 currentAllowance = allowance(owner, _spender);
        require(
            currentAllowance >= _subtractedValue,
            "STV2: decreased allowance below zero"
        );
        unchecked {
            _approve(owner, _spender, currentAllowance - _subtractedValue);
        }

        return true;
    }

    /// @dev Moves `_amount` of tokens from `_from` to `_to`.
    ///      Emits a {Transfer} event
    ///      Requirements:
    ///      * `_from` cannot be the zero address and has to be whitelisted
    ///      * `_to` cannot be the zero address and has to be whitelisted.
    ///      * `_from` must have a balance of at least `amount`.
    ///      Function checks limits, balance of `_from` address => see {_beforeTokenTransfer}
    ///      Function updates DataOfLockedTokens for `_from` address => see {_afterTokenTransfer}
    function _transfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal onlyWhitelisted(_from) onlyWhitelisted(_to) {
        require(_from != address(0), "STV2: transfer from zero address");
        require(_to != address(0), "STV2: transfer to zero address");

        _beforeTokenTransfer(_from, _to, _amount);

        uint256 fromBalance = _balances[_from];
        require(
            fromBalance >= _amount,
            "STV2: transfer amount exceeds balance"
        );
        unchecked {
            _balances[_from] = fromBalance - _amount;
            // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
            // decrementing then incrementing.
            _balances[_to] += _amount;
        }

        emit Transfer(_from, _to, _amount);

        _afterTokenTransfer(_from);
    }

    /// @dev Creates `_amount` tokens and assigns them to `_account`, increasing
    ///      the total supply.
    ///      Emits a {Transfer} event with `from` set to the zero address.
    ///      Requirements:
    ///      `_account` cannot be the zero address and has to be whitelisted.
    function _mint(
        address _account,
        uint256 _amount
    ) internal onlyWhitelisted(_account) {
        require(_account != address(0), "STV2: mint to zero address");

        _validateToInteractSingle(_account);

        _totalSupply += _amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[_account] += _amount;
        }
        emit Transfer(address(0), _account, _amount);
    }

    /// @dev Destroys `_amount` tokens from `_account`, reducing the total supply.
    ///      Emits a {Transfer} event with `to` set to the zero address.
    ///      Requirements:
    ///      * `_account` cannot be the zero address.
    ///      * `_account` must have at least `_amount` tokens.
    function _burn(address _account, uint256 _amount) internal {
        require(_account != address(0), "STV2: burn from zero address");

        uint256 accountBalance = _balances[_account];
        require(accountBalance >= _amount, "STV2: burn amount exceeds balance");

        unchecked {
            _balances[_account] = accountBalance - _amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            _totalSupply -= _amount;
        }

        emit Transfer(_account, address(0), _amount);
    }

    /// @dev Sets `_amount` as the allowance of `_spender` over the `_owner` s tokens.
    ///      This internal function is equivalent to `approve`, and can be used to
    ///      e.g. set automatic allowances for certain subsystems, etc.
    ///      Emits an {Approval} event.
    ///      Requirements:
    ///      *`_owner` cannot be the zero address and has to be whitelisted.
    ///      *`_spender` cannot be the zero address and has to be whitelisted.
    function _approve(
        address _owner,
        address _spender,
        uint256 _amount
    ) internal onlyWhitelisted(_owner) onlyWhitelisted(_spender) {
        require(_owner != address(0), "STV2: approve from zero address");
        require(_spender != address(0), "STV2: approve to zero address");

        _validateToInteractSingle(_spender);

        _allowances[_owner][_spender] = _amount;
        emit Approval(_owner, _spender, _amount);
    }

    /// @dev Updates `_owner` s allowance for `_spender` based on spent `_amount`.
    ///      Does not update the allowance amount in case of infinite allowance.
    ///      Revert if not enough allowance is available.
    ///      Might emit an {Approval} event.
    function _spendAllowance(
        address _owner,
        address _spender,
        uint256 _amount
    ) internal {
        uint256 currentAllowance = allowance(_owner, _spender);
        if (currentAllowance != type(uint256).max) {
            require(
                currentAllowance >= _amount,
                "STV2: insufficient allowance"
            );
            unchecked {
                _approve(_owner, _spender, currentAllowance - _amount);
            }
        }
    }

    /// @dev This hook is called before any transfer of tokens(except minting & burning).
    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal virtual;

    /// @dev This hook is called after any transfer of tokens(except minting & burning).
    function _afterTokenTransfer(address _from) internal virtual;

    function _validateToInteractSingle(address _account) internal view virtual;
}
