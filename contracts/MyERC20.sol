// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

//import "contracts/class/IERC20.sol";
import "contracts/IERC20.sol";
import "contracts/Err.sol";


contract MyERC20 is IERC20 {

    string private constant s_tokenName = "Dean20";
    string private constant s_tokenSymbol = "DTK";
    uint256 private constant MAX_SUPPLY = 30000000000000000000000000;

    uint256 private s_totalSupply;
    address private s_owner;
    uint8 private s_tokenDecimal;

    mapping(address account => uint256 balance) private balances;
    mapping(address account => mapping(address spender => uint256)) private allowances;


    constructor() {
        s_tokenDecimal = 18;
        s_owner = tx.origin;
        initializeOwner();
    }

    function initializeOwner() private {
        uint96 initialSupply = 1000000000000000000000000;
        if (initialSupply > MAX_SUPPLY) revert Err.MAXIMUM_TOKEN_SUPPLY_REACHED();

        s_totalSupply = s_totalSupply + initialSupply;
        balances[msg.sender] = balances[msg.sender] + initialSupply;
    }


    function onlyOwner() private view {
        if (msg.sender != s_owner) revert Err.ONLY_OWNER_IS_ALLOWED();
    }

    function name() external pure returns (string memory) {
        return s_tokenName;
    }

    function symbol() external pure returns (string memory) {
        return s_tokenSymbol;
    }

    function decimals() external view returns (uint8) {
        return s_tokenDecimal;
    }

    function totalSupply() external view returns (uint256) {
        return s_totalSupply;
    }

    function balanceOf(address _user) external view returns (uint256 balance) {
        return balances[_user];
    }

    function transfer(address _to, uint256 _value) external returns (bool) {
        if (_to == address(0) || msg.sender == address(0)) revert Err.ZERO_ADDRESS_NOT_ALLOWED();
        if (s_totalSupply < balances[msg.sender]) revert Err.BALANCE_MORE_THAN_TOTAL_SUPPLY();

        balances[msg.sender] = balances[msg.sender] - _value;
        balances[_to] = balances[_to] + _value;

        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) external returns (bool) {
        if (_to == address(0) || _from == address(0)) revert Err.ZERO_ADDRESS_NOT_ALLOWED();
        if (allowances[_from][_to] < _value) revert Err.INSUFFICIENT_ALLOWANCE_BALANCE();
        if (balances[_from] < allowances[_from][_to]) revert Err.INSUFFICIENT_BALANCE();
        if (s_totalSupply < balances[_from]) revert Err.BALANCE_MORE_THAN_TOTAL_SUPPLY();

        balances[_from] = balances[_from] - _value;
        allowances[_from][_to] = allowances[_from][_to] - _value;

        balances[_to] = balances[_to] + _value;
        emit Transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) external returns (bool) {
        if (_spender == address(0) || msg.sender == address(0)) revert Err.ZERO_ADDRESS_NOT_ALLOWED();
        if (balances[msg.sender] < _value) revert Err.INSUFFICIENT_BALANCE();
        allowances[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) external view returns (uint256 remaining) {
        return allowances[_owner][_spender];
    }

    function mint(address _account, uint256 _amount) public {
        onlyOwner();
        uint256 tempSupply = s_totalSupply + _amount;
        if (tempSupply > MAX_SUPPLY) revert Err.MAXIMUM_TOKEN_SUPPLY_REACHED();

        s_totalSupply = s_totalSupply + _amount;
        balances[_account] = balances[_account] + _amount;
    }

    function burn(uint96 _amount) external {
        if (msg.sender == address(0)) revert Err.ZERO_ADDRESS_NOT_ALLOWED();
        if (balances[msg.sender] <= 0) revert Err.CANNOT_BURN_ZERO_TOKEN();

        balances[msg.sender] = balances[msg.sender] - _amount;
        s_totalSupply = s_totalSupply - _amount;

        balances[address(0)] = balances[address(0)] + _amount;
    }
}
