// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./FomajPrizePool.sol";
/**
 * @title Fomaj
 */
 contract Fomaj is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    Config public config;
    uint256 public currentRoundNumber;

    bool public genesisStartOnce = false;

    uint256 public oracleLatestRoundId; // converted from uint80 (Chainlink)
    uint256 public oracleUpdateAllowance; // seconds

    mapping (address => UserInfo) public userInfo;
    mapping(uint256 => mapping(address => BetInfo)) public ledger;
    mapping(uint256 => Round) public rounds;

    struct Config {
        IERC20 fmjToken;
        FomajPrizePool prizePool;
        uint256 minPrizeAmount;
        int256 betRange;
        uint256 closeTimeMultiplier;
        AggregatorV3Interface oracle;
        uint256 minStakeAmount;
        uint256 stakeLockDuration;
        uint256 minBetAmount;
        uint256 intervalSeconds; 
        uint256 bufferSeconds; 
    }

    enum RoundStatus {
        Invalid,
        Live,
        Expired,
        Cancelled
    }

    struct UserInfo {
        uint256 stakedAmount;
        uint256 unlockTimestamp;
        uint256[] userRounds;
    }

    struct BetInfo {
        Position position;
        uint256 amount;
        bool betAmountClaimed;
        bool winningsClaimed;
    }

    enum Position {
        None,
        Bull,
        Bear,
        Flat
    }

    struct RoundAmounts {
        uint256 bullAmount;
        uint256 bearAmount;
        uint256 flatAmount;
        uint256 totalAmount;
    }

    struct RoundPrices {
        int256 closePrice;
        int256 flatMinPrice;
        int256 flatMaxPrice;
    }

    struct RoundTimestamps {
        uint256 startTimestamp;
        uint256 lockTimestamp;
        uint256 closeTimestamp;
    }

    struct RoundOracleIds {
        uint256 startOracleId;
        uint256 lockOracleId;
        uint256 closeOracleId;
    }

    enum RewardStatus {
        NotCalculated,
        Calculated,
        NoWinners,
        Cancelled
    }

    struct RoundRewards {
        RewardStatus status;
        Position winner;
        uint256 amount;
    }

    struct Round {
        uint256 roundNumber;
        RoundStatus status;
        RoundPrices prices;
        RoundOracleIds oracleIds;
        RoundTimestamps timestamps;
        RoundAmounts amounts;
        RoundRewards rewards;
    }

    event KickOff(
        Config _config
    );
    event ChangeOwner(address indexed newOwner);
    event Staked(address indexed staker, uint256 amount, uint256 totalStaked);
    event UnStaked(address indexed staker, uint256 amount);

    event BetBear(address indexed sender, uint256 indexed epoch, uint256 amount);
    event BetBull(address indexed sender, uint256 indexed epoch, uint256 amount);
    event BetFlat(address indexed sender, uint256 indexed epoch, uint256 amount);
    event EndRound(uint256 indexed roundNumber, uint256 indexed roundId, int256 price);
    event StartRound(uint256 indexed roundNumber, uint256 indexed roundId, int256 price);

    modifier notContract() {
        require(!_isContract(msg.sender), "Contract not allowed");
        require(msg.sender == tx.origin, "Proxy contract not allowed");
        _;
    }

    modifier hasStakedEnough() {
        require(userInfo[msg.sender].stakedAmount >= config.minStakeAmount, "Stake requirments not met.");
        _;
    }
    
    constructor() {
        // Deployment doesn't take any params.
        // An admin has to call `kickOff` with required config to kick off :). 
       _pause();
    }

     
    /**
     * @notice called by the admin upause
     * @dev Callable by admin or operator
     */
    function kickOff(
            Config memory _config
        ) external onlyOwner {
        require(_config.minStakeAmount != 0, "Minimum stake ammount cannot be zero.");
        require(_config.betRange <= 10 && _config.betRange > 0, "Invalid bet range.");
        require(_config.stakeLockDuration != 0, "Stake duration cannot be zero.");
        require(_config.minBetAmount != 0, "Minimum bet cannot be zero.");
        require(_config.intervalSeconds != 0, "Invalid interval seconds.");
        require(_config.closeTimeMultiplier != 0, "Invalid lock time");
        require(_config.bufferSeconds != 0, "Invalid buffer seconds.");
        require(_config.intervalSeconds > _config.bufferSeconds, "Interval must be higher than buffer.");

        config.fmjToken = _config.fmjToken;
        config.minStakeAmount = _config.minStakeAmount;
        config.stakeLockDuration = _config.stakeLockDuration;

        config.oracle = _config.oracle;
        // dummy oracle call
        _config.oracle.latestRoundData();
        
        config.minBetAmount = _config.minBetAmount;
        config.betRange = _config.betRange;

        config.intervalSeconds = _config.intervalSeconds;
        config.bufferSeconds = _config.bufferSeconds;

        config.prizePool = _config.prizePool;
        config.minPrizeAmount = _config.minPrizeAmount;
        config.closeTimeMultiplier = _config.closeTimeMultiplier;
        _unpause();
        emit KickOff(_config);
    }

    /**
     * @notice called by the owner to pause, triggers stopped state
     * @dev Callable by owner
     */
    function pause() external whenNotPaused onlyOwner {
        _pause();
    }

    /**
     * @notice When the system is matured enough to govern on its own,
               this function will be called to transfer ownership to a 
               governance contract.
     * @dev Callable by admin or operator
     */
    function changeOwnership(address newOwner) external whenPaused onlyOwner {
        require(newOwner != address(0), "Invalid address provided");
        transferOwnership(newOwner);
        emit ChangeOwner(newOwner);
    }

    function stake(uint256 value) external whenNotPaused {
        UserInfo storage user = userInfo[msg.sender];
        uint256 currentStake = user.stakedAmount;
        require(currentStake < config.minStakeAmount, "Already staking required amount.");

        uint256 requiredAmount = config.minStakeAmount - currentStake;

        IERC20 token = config.fmjToken; // gas savings

        if (requiredAmount == value) {
            token.safeTransferFrom(msg.sender, address(this), requiredAmount);
            user.unlockTimestamp = block.timestamp + config.stakeLockDuration;
            user.stakedAmount = config.minStakeAmount;
        } else if (value > requiredAmount) {
            token.safeTransferFrom(msg.sender, address(this), requiredAmount);
            token.safeTransfer(msg.sender, (value - requiredAmount));
            user.unlockTimestamp = block.timestamp + config.stakeLockDuration;
            user.stakedAmount = config.minStakeAmount;
        } else {
            token.safeTransferFrom(msg.sender, address(this), value);
            user.stakedAmount = currentStake + value;
        }
        emit Staked(msg.sender, value, user.stakedAmount);
    }

    function unstake() external {
        UserInfo storage user = userInfo[msg.sender];
        uint256 currentStake = user.stakedAmount;
        require(currentStake != 0, "Not staking!");

        if (currentStake >= config.minStakeAmount) {
            require(block.timestamp > user.unlockTimestamp, "Cannot unlock stake yet");
        }

        config.fmjToken.safeTransfer(msg.sender, currentStake);
        emit UnStaked(msg.sender, user.stakedAmount);
        user.stakedAmount = 0;
    }
    
    /**
     * @notice Bet bull position
     * @param roundNumber: roundNumber
     * @param value: amount
     */
    function betBull(uint256 roundNumber, uint256 value) external whenNotPaused nonReentrant notContract hasStakedEnough {
        require(roundNumber == currentRoundNumber, "Bet is too late");
        Round storage round = rounds[roundNumber];
        require(round.status == RoundStatus.Live, "Round not bettable");
        require(block.timestamp < round.timestamps.lockTimestamp, "Round locked");

        require(value >= config.minBetAmount, "Bet amount must be greater than minBetAmount");
        require(ledger[roundNumber][msg.sender].amount == 0, "Can only bet once per round");

        config.fmjToken.safeTransferFrom(msg.sender, address(this), value);

        // Update round data
        round.amounts.bullAmount = round.amounts.bullAmount + value;
        round.amounts.totalAmount = round.amounts.totalAmount + value;

        // Update user data
        BetInfo storage betInfo = ledger[roundNumber][msg.sender];
        betInfo.position = Position.Bull;
        betInfo.amount = value;
        userInfo[msg.sender].userRounds.push(roundNumber);

        emit BetBull(msg.sender, roundNumber, value);
    }

    /**
     * @notice Bet bear position
     * @param roundNumber: roundNumber
     * @param value: amount to bet
     */
    function betBear(uint256 roundNumber, uint256 value) external payable whenNotPaused nonReentrant notContract {
        require(roundNumber == currentRoundNumber, "Bet is too early/late");
        Round storage round = rounds[roundNumber];
        require(round.status == RoundStatus.Live, "Round not bettable");
        require(block.timestamp < round.timestamps.lockTimestamp, "Round locked");

        require(value >= config.minBetAmount, "Bet amount must be greater than minBetAmount");
        require(ledger[roundNumber][msg.sender].amount == 0, "Can only bet once per round");

        config.fmjToken.safeTransferFrom(msg.sender, address(this), value);

        // Update round data
        round.amounts.bearAmount = round.amounts.bearAmount + value;
        round.amounts.totalAmount = round.amounts.totalAmount + value;

        // Update user data
        BetInfo storage betInfo = ledger[roundNumber][msg.sender];
        betInfo.position = Position.Bear;
        betInfo.amount = value;
        userInfo[msg.sender].userRounds.push(roundNumber);

        emit BetBear(msg.sender, roundNumber, value);
    }

    /**
     * @notice Bet bear position
     * @param roundNumber: roundNumber
     * @param value: amount to bet
     */
    function betFlat(uint256 roundNumber, uint256 value) external payable whenNotPaused nonReentrant notContract {
        require(roundNumber == currentRoundNumber, "Bet is too late");
        Round storage round = rounds[roundNumber];
        require(round.status == RoundStatus.Live, "Round not bettable");
        require(value >= config.minBetAmount, "Bet amount must be greater than minBetAmount");
        require(ledger[roundNumber][msg.sender].amount == 0, "Can only bet once per round");

        config.fmjToken.safeTransferFrom(msg.sender, address(this), value);

        // Update round data
        round.amounts.flatAmount = round.amounts.flatAmount + value;
        round.amounts.totalAmount = round.amounts.totalAmount + value;

        // Update user data
        BetInfo storage betInfo = ledger[roundNumber][msg.sender];
        betInfo.position = Position.Flat;
        betInfo.amount = value;
        userInfo[msg.sender].userRounds.push(roundNumber);

        emit BetFlat(msg.sender, roundNumber, value);
    }

    /**
     * @notice Start the next round n, lock price for round n-1, end round n-2
     * @dev Callable by operator
     */
    function executeRound() external whenNotPaused onlyOwner {
        require(genesisStartOnce, "Can only run after genesisStartRound is triggered");

        (uint80 currentRoundId, int256 currentPrice) = _getPriceFromOracle();

        oracleLatestRoundId = uint256(currentRoundId);

        // end old round
        _safeEndRound(currentRoundNumber, currentRoundId, currentPrice);
        _calculateRewards(currentRoundNumber);

        // start new round
        currentRoundNumber = currentRoundNumber + 1;
        _safeStartRound(currentRoundNumber, currentRoundId, currentPrice);
    }

    /**
     * @notice Start genesis round
     * @dev Callable by admin or operator
     */
    function genesisStartRound() external whenNotPaused onlyOwner {
        require(!genesisStartOnce, "Can only run genesisStartRound once");

        (uint80 currentRoundId, int256 currentPrice) = _getPriceFromOracle();

        oracleLatestRoundId = uint256(currentRoundId);

        currentRoundNumber = currentRoundNumber + 1;
        _startRound(currentRoundNumber, currentRoundId, currentPrice);
        genesisStartOnce = true;
    }

    /**
     * @notice Claim winnings
     * @param roundNumbers: roundNumbers
     */
    function claimWinnings(uint256[] calldata roundNumbers) external nonReentrant notContract {
        uint256 reward;

        for (uint256 i = 0; i < roundNumbers.length; i++) {
            uint256 roundNumber = roundNumbers[i];
            Round memory round = rounds[roundNumber];
             if(hasWinnings(roundNumber, msg.sender)) {
                    BetInfo storage betInfo = ledger[roundNumber][msg.sender];
                    betInfo.winningsClaimed = true;
                    uint256 q = round.amounts.flatAmount;
                    if(round.rewards.winner == Position.Bull) {
                        q = round.amounts.bullAmount;
                    } else if(round.rewards.winner == Position.Bear) {
                        q = round.amounts.bearAmount;
                    }
                    reward = reward + (round.rewards.amount * betInfo.amount)/q;
                }
        }

        if(reward > 0) {
            config.fmjToken.transferFrom(address(config.prizePool), msg.sender, reward);
            config.prizePool.markPrizeSent(reward);
        }
    }

     /**
     * @notice Claim locked funds
     * @param roundNumbers: roundNumbers
     */
    function claimLockedFunds(uint256[] calldata roundNumbers) external nonReentrant notContract {
        uint256 fund;

        for (uint256 i = 0; i < roundNumbers.length; i++) {
            uint256 roundNumber = roundNumbers[i];
                if(hasLockedFunds(roundNumber, msg.sender)) {
                    BetInfo storage betInfo = ledger[roundNumber][msg.sender];
                    betInfo.betAmountClaimed = true;
                    fund = fund + betInfo.amount;
                }
        }

        if(fund > 0) {
            config.fmjToken.transfer(msg.sender, fund);
        }
    }


    /**
     * @notice Get the claimable stats of specific round and user account
     * @param roundNumber: roundNumber
     * @param user: user address
     */
    function hasWinnings(uint256 roundNumber, address user) public view returns (bool) {
        BetInfo memory betInfo = ledger[roundNumber][user];
        Round memory round = rounds[roundNumber];

        if (round.rewards.status != RewardStatus.Calculated) {
            // no winners, not calculated
            return false;
        }

        if (betInfo.amount == 0) {
            // user didn't bet on the outcome
            return false;
        }

        if (betInfo.winningsClaimed) {
            // winnings already claimed
            return false;
        }

        return round.rewards.winner == betInfo.position;
    }

    /**
     * @notice Get the claimable state of locked funds of a specific user
     * @param roundNumber: roundNumber
     * @param user: user address
     */
    function hasLockedFunds(uint256 roundNumber, address user) public view returns (bool) {
        BetInfo memory betInfo = ledger[roundNumber][user];
        Round memory round = rounds[roundNumber];

        if (!((round.status == RoundStatus.Expired) || (round.status == RoundStatus.Cancelled))) {
            // no winners, not calculated
            return false;
        }

        if (betInfo.amount == 0) {
            // user didn't bet on the outcome
            return false;
        }

        if (betInfo.betAmountClaimed) {
            // already claimed
            return false;
        }

        return true;
    }

    /**
     * @notice It allows the owner to recover tokens sent to the contract by mistake
     * @param _token: token address
     * @param _amount: token amount
     * @dev Callable by owner
     */
    function recoverToken(address _token, uint256 _amount) external onlyOwner {
        IERC20(_token).safeTransfer(address(msg.sender), _amount);
    }

    function userRounds(address user) view external returns(uint256[] memory){
        return userInfo[user].userRounds;
    }
    /**
     * @notice Calculate rewards for round
     * @param roundNumber: roundNumber
     */
    function _calculateRewards(uint256 roundNumber) internal {
        Round storage round = rounds[roundNumber]; 
        require(round.status == RoundStatus.Expired, "Too early");
        require(round.rewards.status == RewardStatus.NotCalculated, "Cannot calculate rewards");
       
        // not enough funds to calculate prize
        uint256 prizePool = config.prizePool.prizePoolAmount();
       
        bool bullWins = round.prices.closePrice > round.prices.flatMaxPrice;
        bool bearWins = round.prices.closePrice < round.prices.flatMinPrice;
        bool flatWins = !(bullWins || bearWins);

        bool hasPrize = prizePool > config.minPrizeAmount;
        
        if(bullWins) {
            round.rewards.winner = Position.Bull;
            if(hasPrize && round.amounts.bullAmount != 0) {
                round.rewards.amount = prizePool;
                config.prizePool.reservePrizeAmount(prizePool);
                
            }

        }

        if(bearWins) {
            round.rewards.winner = Position.Bear;
            if(hasPrize && round.amounts.bearAmount != 0) {
                 round.rewards.amount = prizePool;
                 config.prizePool.reservePrizeAmount(prizePool);
            }
        }

        if(flatWins) {
            round.rewards.winner = Position.Flat;
            if(hasPrize && round.amounts.flatAmount != 0) {
                round.rewards.amount = prizePool;
                config.prizePool.reservePrizeAmount(prizePool);
            }
        }

        if(!hasPrize) {
            round.rewards.status = RewardStatus.Cancelled;
        } else {
            round.rewards.status = RewardStatus.Calculated;
        }
    }
    
    /**
     * @notice Start round
     * Previous round n-1 must end
     * @param roundNumber: roundNumber
     */
    function _safeStartRound(uint256 roundNumber, uint256 roundId,
        int256 price) internal {
        require(genesisStartOnce, "Can only run after genesisStartRound is triggered");
        require(rounds[roundNumber - 1].status == RoundStatus.Expired, "Can only start round after round n-1 has ended");
        _startRound(roundNumber, roundId, price);
    }

    /**
     * @notice Start round
     * @param roundNumber: roundNumber
     */
    function _startRound(uint256 roundNumber, uint256 roundId,
        int256 price) internal {
        Round storage round = rounds[roundNumber];
        round.timestamps.startTimestamp = block.timestamp;
        /**
        * If interval is 30 minutes, and closeTimeMultiplier is 4.
        * Users have 30 minutes to place bets.
        * After 4 * 30 = 120 minutes the round is closed.
         */
        round.timestamps.lockTimestamp = block.timestamp + config.intervalSeconds;
        round.timestamps.closeTimestamp = block.timestamp + (config.closeTimeMultiplier * config.intervalSeconds);
        round.roundNumber = roundNumber;

        int difference = (price * config.betRange)/200;
        round.prices.flatMinPrice = price - difference;
        round.prices.flatMaxPrice = price + difference;
        round.oracleIds.startOracleId = roundId;
        round.status = RoundStatus.Live;
        emit StartRound(roundNumber, roundId, price);
    }


    /**
     * @notice End round
     * @param roundNumber: epoch
     * @param roundId: roundId
     * @param price: price of the round
     */
    function _safeEndRound(
        uint256 roundNumber,
        uint256 roundId,
        int256 price
    ) internal {
        // TODO: Enable/Remove these once blocktime in polyjuice is finalized (nodes, mining etc)
        // require(block.timestamp >= rounds[roundNumber].timestamps.closeTimestamp, "Can only end round after closeTimestamp");
        // require(
        //     block.timestamp <= rounds[roundNumber].timestamps.closeTimestamp + config.bufferSeconds,
        //     "Can only end round within bufferSeconds"
        // );
        Round storage round = rounds[roundNumber];
        round.prices.closePrice = price;
        round.oracleIds.closeOracleId = roundId;
        round.status = RoundStatus.Expired;
        emit EndRound(roundNumber, roundId, price);
    }

    function _getPriceFromOracle() internal view returns (uint80, int256) {
        (uint80 roundId, int256 price,,,) = config.oracle.latestRoundData();
        // TODO: stricly check oracle timestamp allowance 
        // once polyjuice has a proper oracle
        return (roundId, price);
    }

    /**
     * @notice Returns true if `account` is a contract.
     * @param account: account address
     */
    function _isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
 }