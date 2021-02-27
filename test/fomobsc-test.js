const { expect } = require("chai");

let owner;
let player1;
let player2;

let fomoBSC;
let fomoBSCAsPlayer1;
let fomoBSCAsPlayer2;

// Round Index
let roundID = 0;
let winner = 1;
let gameStartTime = 2;
let gameEndTime = 3;
let totalKeys = 4;
let keyPrice = 5;
let pot = 6;
let players = 7;

beforeEach(async function () {
  // Get the ContractFactory and Signers here.
  const FomoBSC = await ethers.getContractFactory("FomoBSC");
  [owner, player1, player2] = await ethers.getSigners();

  // To deploy our contract, we just have to call Token.deploy() and await
  // for it to be deployed(), which happens onces its transaction has been
  // mined.
  fomoBSC = await FomoBSC.deploy();
  fomoBSCAsPlayer1 = fomoBSC.connect(player1);
  fomoBSCAsPlayer2 = fomoBSC.connect(player2);
  // 0x5e93F10bD33b5A7ad362e675aD0564ad48b22833 - Owner Address
  // 0xFb11d1eDa988AFBED348d137617cC7bDB0b6E9bA - Player 1 Address
  // 0x0aCaF822BBE73344907132AdB1e25752356de1Da - Player 2 Address
});

describe("FomoBSC", function() {
  /*
  it("Deployment should assign the fields properly", async function() {

    const roundInfo = await fomoBSC.getRoundInfo();
    expect(roundInfo[roundID]).to.equal(1);
    expect(roundInfo[winner]).to.equal(owner.address);
    expect(roundInfo[gameStartTime]).to.equal(roundInfo[3] - 86400);
    //expect(roundInfo[gameEndTime]).to.equal(roundInfo[2] + 86400);
    expect(roundInfo[totalKeys]).to.equal(0);
    expect(roundInfo[keyPrice]).to.equal(1000);
    expect(roundInfo[pot]).to.equal(0);
    expect(roundInfo[players][0]).to.equal(owner.address);
  });*/

  it("Buy keys", async function() {
    this.timeout(0);  
    
    let roundInfo = await fomoBSC.getCurrentRoundInfo();
    let firstEnd = roundInfo[gameEndTime];

    await expect(fomoBSC.buyKeys(1000, {gasLimit: 2000000, value: "100000000000000"})).to.emit(fomoBSC, 'PotIncreased').withArgs(owner.address, "55000000000000", "100010000000000");
    roundInfo = await fomoBSC.getCurrentRoundInfo();
    let secondEnd = firstEnd.add(30);
    expect(roundInfo[roundID]).to.equal(1);
    expect(roundInfo[winner]).to.equal(owner.address);
    expect(roundInfo[totalKeys]).to.equal("1000");
    expect(roundInfo[keyPrice]).to.equal("100010000000000");
    expect(roundInfo[pot]).to.equal("55000000000000");
    expect(roundInfo[gameEndTime]).to.equal(secondEnd);

    await fomoBSCAsPlayer1.joinGame("Player 1")
    await expect(fomoBSCAsPlayer1.buyKeys(1500, {gasLimit: 2000000, value: "200030001000000"})).to.emit(fomoBSCAsPlayer1, 'PotIncreased').withArgs(player1.address, "165016500550000", "100030003000100");
    roundInfo = await fomoBSCAsPlayer1.getCurrentRoundInfo();
    let thirdEnd = secondEnd.add(30);
    expect(roundInfo[winner]).to.equal(player1.address);
    expect(roundInfo[totalKeys]).to.equal("2500");
    expect(roundInfo[keyPrice]).to.equal("100030003000100");
    expect(roundInfo[pot]).to.equal("165016500550000");
    expect(roundInfo[gameEndTime]).to.equal(thirdEnd);
  });

});
