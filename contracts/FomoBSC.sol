//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract FomoBSC {

    struct Player { 
        address addr;
        string name;
        bool valid;
    }

    struct Round { 
        uint roundID;

        address winner;
        uint gameStartTime;
        uint gameEndTime;

        uint totalKeys;
        uint keyPrice;
        uint keyPot;

        uint totalShares;
        uint profitPerShare;
        uint dividendPot;

        uint teamDistribution;

        uint players;
    }

    struct Vault {
        uint bnbInvested;
        uint shares;
        uint keys;

        uint affiliateRewards;
        uint winnerRewards;

        bool valid;
    }

    address public creator;

    // BNB decimals
    uint constant bnbDecimals = 1000000000000000000;
    // Starting 0.0001 BNB price
    uint constant startingPrice = 1 * bnbDecimals / 10000;
    // 1 BNB
    uint constant maxPurchase = 1 * bnbDecimals;
    // 200 BNB
    uint constant limitRemoved = 200 * bnbDecimals;

    // 0.01 percent multiplier
    uint constant multiplier = 10000;
    // 24 hours
    uint constant maxSeconds = 86400;
    // 1 hour
    uint constant bufferSeconds = 3600;

    uint constant potWithoutAffDistribution = 55;
    uint constant potWithAffDistribution = 45;
    uint constant affiliateDistribution = 10;
    uint constant holderDistribution = 40;
    uint constant teamDistribution = 5;
    uint constant winnerDistribution = 50;
    uint constant holderEndingDistribution = 40;
    uint constant newRoundSeed = 10;

    // Map address to their affiliates
    mapping(address => address) public affiliates;

    // Map address to their array index
    mapping(address => Player) public players;

    // Map roundID to their array index
    mapping(uint => Round) public rounds;

    // Round ID -> Player Addr -> Vault
    mapping(uint => mapping(address => Vault)) public vaults;

    uint public roundID;
    uint public totalPlayers;

    // Events that will be emitted on changes.
    event PotIncreased(address winner, uint pot, uint keyAmount);
    event GameEnded(address winner, uint amount);

    /// Create a game.
    constructor() public {
        creator = msg.sender;
        roundID = 1;
        totalPlayers = 1;
        uint gameStartTime = block.timestamp;
        uint gameEndTime = gameStartTime + maxSeconds;
        players[msg.sender] = Player(creator, 'Team', true);
        // address[] memory declareTeam = new address[](1); 
        // declareTeam[0] = creator;
        rounds[roundID] = Round(roundID, creator, gameStartTime, gameEndTime, 0, startingPrice, 0, 0, 0);
        vaults[roundID][msg.sender] = Vault(0, 0, 0, 0, true);

        console.log("Deploying FomoBSC with creator: ", msg.sender);
    }

    /// Join the game.
    function joinGame(string memory _name) public {

        require(
            !players[msg.sender].valid,
            "You have already joined."
        );

        // Start from index 1
        totalPlayers += 1;
        players[msg.sender] = Player(msg.sender, _name, true);

    }

    /// Join the game with affiliate address.
    function joinGameWithAddr(string memory _name, address _address) public {

        require(
            players[_address].valid,
            "Affiliate does not exist."
        );

        require(
            !players[msg.sender].valid,
            "You have already joined."
        );

        // Start from index 1
        totalPlayers += 1;
        players[msg.sender] = Player(msg.sender, _name, true);
        rounds[roundID].players += 1;
        // Sender only 1 upline
        affiliates[msg.sender] = _address;

    }

    /// Buy keys with BNB sent
    /// together with this transaction.
    function buyKeys(uint _keyAmount) public payable {
        // The keyword payable
        // is required for the function to
        // be able to receive BNB.

        // Revert the call if game is over or not started.
        require(
            block.timestamp >= rounds[roundID].gameStartTime,
            "Round not started. Please wait."
        );

        require(
            block.timestamp <= rounds[roundID].gameEndTime,
            "Round ended. Please wait for next round."
        );

        // Remove the limit when pot reaches 200 BNB
        if(rounds[roundID].keyPot < limitRemoved){
          require(
              msg.value <= maxPurchase,
              "You can only purchase 1 BNB worth of keys until pot reaches 200 BNB."
          );
        }

        // If sent BNB is insufficient for key amount, send the
        // money back.
        uint totalBNB = 0;
        uint newKeyPrice = rounds[roundID].keyPrice;
        
        // 1 key = 1000 key amount ( accept 3 decimals ). Need to ceil the amount
        uint len = _keyAmount / 1000 + 1;
        for(uint i = 0; i < len; i++){
            if(i == len - 1){
                // LAST
                totalBNB += newKeyPrice * (_keyAmount % 1000) / 1000;
            } else {
                totalBNB += newKeyPrice;
            }
            newKeyPrice = newKeyPrice + newKeyPrice / multiplier;
            if(_keyAmount == 1000){
              // Skip the loop if key is exact 1000
              break;
            }
        }
    
        require(
            msg.value >= totalBNB,
            "Total BNB sent does not meet total key price."
        );

        // Update current key price.
        rounds[roundID].keyPrice = newKeyPrice;
        rounds[roundID].totalKeys += _keyAmount;
        
        vaults[roundID][msg.sender].bnbInvested += msg.value;
        vaults[roundID][msg.sender].keys += _keyAmount;

        // Record how much each player bought and distribute dividends.
        /*
        bool playerExists = false;
        uint dividends = msg.value * holderDistribution / 100;
        for(uint i = 0; i < rounds[roundID].players.length; i++){
          address currentAddr = rounds[roundID].players[i];
          if(currentAddr == msg.sender){
              playerExists = true;
          }
          if(!vaults[roundID][currentAddr].valid){
            vaults[roundID][currentAddr] = Vault(0, 0, 0, 0, true);
          }
          vaults[roundID][currentAddr].rewards += dividends / rounds[roundID].totalKeys * vaults[roundID][currentAddr].keys;
        }
        if (!playerExists) {
          rounds[roundID].players.push(msg.sender); 
        }*/

        // If more than 1 key, set sender to winner and add time. 1000 = 1 key
        if (_keyAmount >= 1000) {
          rounds[roundID].winner = msg.sender;
          // Increase 30 seconds with every 1 key bought. Floor the key.
          rounds[roundID].gameEndTime += _keyAmount * 30 / 1000;
        }

        // Start distribution
        // assume max share 
        // Dividends
        // Player 1 puts in 1 BNB
        // Dividend pot has 0.4 BNB
        // Player 1 has 1 share

        // Player 2 puts in 1.001 BNB
        // Dividend pot has 0.8004 BNB
        // Player 2 has 1 share
        // Player 1 receives 0.4004 BNB

        // Player 3 puts in 1.002001 BNB
        // Dividend pot has 1.2012004 BNB 
        // Player 3 has 1 shares;
        // 1.2012004 - previous den divide 
        // Player 1 receives 0.2004002 BNB received total - 0.6008002 = 0.500166500 * 1.2012004 -> 1
        // Player 2 receives 0.2004002 BNB received total - 0.2004002 = 0.166833277 * 1.2012004 -> 0.333555
        // Need to count the last pot but not the last person shares . 0.8012004
        //Player 2 puts in 1.001 BNB
        // Player 1 gets 0.4004
        // Player 3 puts in 1.002001 BNB, Player 1 and 2 gets 0.6008002, 0.2004002
        // 
        // Player 1 - 0.7498 , Player 2 - 0.2502
        // 0.4004 + 0.4008004 = 0.8012004
        // 40% goes to current key holders as dividends (4 BNB shared among current key holders)
        // uint dividends = msg.value * holderDistribution / 100;
        // dividends / rounds[roundID].totalKeys * vaults[roundID][currentAddr].keys;

        // First player dividend will be added to pot
        if(rounds[roundID].players > 0){
            rounds[roundID].dividendPot += msg.value * holderDistribution / 100;
        } else {
            rounds[roundID].keyPot += msg.value * holderDistribution / 100;
        }

        uint mintShares = vaults[roundID][msg.sender].keys / rounds[roundID].dividendPot;
        // first - 2.5 shares , 0.4 BNB
        // second - 1.249          , 0.8004
        // third - 
        vaults[roundID][affiliates[msg.sender]].shares += mintShares;
        rounds[roundID].totalShares += mintShares;

        // If buyer has upline
        if(affiliates[msg.sender] != address(0)){
          rounds[roundID].keyPot += msg.value * potWithAffDistribution / 100;
          vaults[roundID][affiliates[msg.sender]].affiliateRewards += msg.value * affiliateDistribution / 100;
        } else {
          rounds[roundID].keyPot += msg.value * potWithoutAffDistribution / 100;
        }

        rounds[roundID].teamDistribution += msg.value * teamDistribution / 100;
        rounds[roundID].players += 1;

        emit PotIncreased(rounds[roundID].winner, rounds[roundID].keyPot, rounds[roundID].keyPrice);

        // Refund spillage
        if(msg.value > totalBNB){
            payable(msg.sender).send(msg.value - totalBNB);
        }
    }

    /// Withdraw rewards.
    function withdraw(uint _roundID) public returns (bool) {

      // Revert the call if player 
      // does not exist.
      require(
          players[msg.sender].valid,
          "Player does not exist."
      );

      uint amount = vaults[_roundID][msg.sender].rewards;

      require(
          amount != 0,
          "No rewards."
      );

      // It is important to set this to zero because the recipient
      // can call this function again as part of the receiving call
      // before `send` returns.
      vaults[_roundID][msg.sender].rewards = 0;

      if (!payable(msg.sender).send(amount)) {
          // No need to call throw here, just reset the amount owing
          vaults[_roundID][msg.sender].rewards = amount;
          return false;
      }
  
      return true;
    }

    /// End the game and add pot to the winner rewards.
    function gameEnd() public {

        require(block.timestamp >= rounds[roundID].gameEndTime, "Game not yet ended.");

        emit GameEnded(rounds[roundID].winner, rounds[roundID].keyPot);

        // Distribute 50% pot to winner
        vaults[roundID][rounds[roundID].winner].winnerRewards = rounds[roundID].keyPot * winnerDistribution / 100;

        // Restart Round.
        roundID += 1;
        // Wait 1 hr for game to be started.
        uint gameStartTime = block.timestamp + bufferSeconds;
        uint gameEndTime = gameStartTime + maxSeconds;
        uint seed = rounds[roundID].keyPot * newRoundSeed / 100;
        // address[] memory declareTeam = new address[](1); 
        // declareTeam[0] = creator;
        rounds[roundID] = Round(roundID, creator, gameStartTime, gameEndTime, 0, startingPrice, 0, seed, 0);
    }

    function getRewards(uint _roundID) public view returns(uint) {  
        Round memory vault = vaults[_roundID][msg.sender];
        uint totalRewards = 0;
        
        if(block.timestamp > rounds[roundID].gameEndTime){
            uint totalHolderDistribution = rounds[roundID].keyPot * holderEndingDistribution / 100;
            totalRewards += totalHolderDistribution * vault.keys / rounds[roundID].totalKeys;
        }

        totalRewards += vault.winnerRewards;
        totalRewards += vault.affiliateRewards;
        return totalRewards;
    }

    function getRoundInfo(uint _roundID) public view returns(uint, address, uint, uint, uint, uint, uint, address[] memory) {
        Round memory currentRound = rounds[_roundID];
        return (currentRound.roundID, currentRound.winner, currentRound.gameStartTime, currentRound.gameEndTime, currentRound.totalKeys, currentRound.keyPrice, currentRound.keyPot, currentRound.players);
    }

    function getCurrentRoundInfo() public view returns(uint, address, uint, uint, uint, uint, uint, address[] memory) {  
        Round memory currentRound = rounds[roundID];
        return (currentRound.roundID, currentRound.winner, currentRound.gameStartTime, currentRound.gameEndTime, currentRound.totalKeys, currentRound.keyPrice, currentRound.keyPot, currentRound.players);
    }
}