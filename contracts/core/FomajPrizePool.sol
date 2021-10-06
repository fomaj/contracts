// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.4;

import "./Fomaj.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract FomajPrizePool is Ownable {
    using SafeERC20 for IERC20;

    address public prediction;
    address public token;
    uint256 public prizeAmount;

    constructor (address _prediction) {
        prediction = _prediction;
        token = address(0);
    }

    function setToken(address _token) external onlyOwner {
        token = _token;
        approve();
    }

    function reservePrizeAmount(uint256 amount) external {
        require(msg.sender == prediction, "Only fomaj contract can call this function");
        prizeAmount += amount;
    }

    function markPrizeSent(uint256 amount) external {
        require(msg.sender == prediction, "Only fomaj contract can call this function");
        prizeAmount -= amount;
    }

    function prizePoolAmount() external view returns (uint256) {
        uint256 balance = IERC20(token).balanceOf(address(this));
        return balance - prizeAmount;
    }

    function setPrediction(address _prediction) external onlyOwner {
        prediction = _prediction;
        approve();
    }

    function approve() internal {
        IERC20(token).safeApprove(prediction, type(uint256).max);
    }
}