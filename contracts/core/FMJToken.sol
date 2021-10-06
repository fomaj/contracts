// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FMJToken is IERC20, Ownable {
    using Address for address;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) excludedFromFees;

    uint _totalSupply = 1000000000; // one billion
    address payable prizePool;

    // goes to the prize pool in each transaction
    uint256 txPoolPercentage; // 10 = 1%, 5 = 0.5% 

    constructor (address payable _prizePool, uint256 _poolPercentage, address faucet) {
        setPrizePool(_prizePool);
        setTxFees(_poolPercentage);

        // this is temporary
        // tokens will be distributed fairly
        _balances[faucet] = _totalSupply;
    }

    function name() public pure returns (string memory) {
        return "FOMAJ";
    }

    function symbol() public pure returns (string memory) {
        return "FMJ";
    }

    function decimals() public pure returns (uint8) {
        return 0; // No decimals
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }


    function setPrizePool(address payable _prizePool) public onlyOwner {
        require(_prizePool != address(0), "Zero address specified.");
        excludeFromFees(_prizePool);
        prizePool = _prizePool;
    }

    function setTxFees(uint256 percentage) public onlyOwner {
        require(percentage <= 100, "Transaction fees cannot exceed 10%");
        txPoolPercentage = percentage;
    }

    function excludeFromFees(address addressToExclude) public onlyOwner {
        excludedFromFees[addressToExclude] = true;
    }

    function includeInFees(address addressToInclude) public onlyOwner {
        require(addressToInclude != prizePool, "Cannot include prizePool in fees");
        excludedFromFees[addressToInclude] = false;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }
    
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");


        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        
        if(excludedFromFees[sender] || excludedFromFees[recipient]) {
            _balances[recipient] += amount;
        } else {
            // calcuate transaction fees that goes to the pool
            // 10 = 1%, 5 = 0.5%
            uint256 txFees = (amount * txPoolPercentage)/1000;

            uint256 recipientAmount = amount - txFees;
            _balances[recipient] += recipientAmount;
            _balances[prizePool] += (amount - recipientAmount);            
        }
        emit Transfer(sender, recipient, amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
} 