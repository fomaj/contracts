// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FMJFaucet is Ownable {

    using SafeERC20 for IERC20;
    address public token;
    uint256 amount;

    constructor (uint256 _amount) {
        require(_amount > 0, "Invalid amount");
        // token is set later
        token = address(0);
        amount = _amount;
    }

    function setToken(address _token) external onlyOwner {
        token = _token;
    }

    function setAmount(uint256 _amount) external onlyOwner {
        require(_amount > 0, "Invalid amount");
        amount = _amount;
    }

    function requestToken() external {
        require(token != address(0), "Token not set");
        IERC20(token).safeTransfer(msg.sender, amount);
    }
}