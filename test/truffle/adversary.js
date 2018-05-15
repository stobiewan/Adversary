const Adversary = artifacts.require("Adversary");
const DSToken = artifacts.require("DSToken");

contract('Offers test', async (accounts) => {

  var adversaryInstance;
  var fakeDaiInstance;
  const offerMakerIndex = 0;
  const offerDaiIndex = 3;
  const escrowDaiIndex = 4;

  it("check fake Dai has been setup", async () => {
     adversaryInstance = await Adversary.deployed();
     fakeDaiInstance = await DSToken.deployed();
     let accountOneDai = await fakeDaiInstance.balanceOf.call(accounts[0]);
     let accountTwoDai = await fakeDaiInstance.balanceOf.call(accounts[1]);
     let accountThreeDai = await fakeDaiInstance.balanceOf.call(accounts[2]);
     assert.equal(accountOneDai, 800);
     assert.equal(accountTwoDai, 100);
     assert.equal(accountThreeDai, 100);
  });

  it("create offers and test dai", async () => {
    await fakeDaiInstance.approve(adversaryInstance.address, 50, {from: accounts[1]});
    await fakeDaiInstance.approve(adversaryInstance.address, 50, {from: accounts[0]});
    await fakeDaiInstance.approve(adversaryInstance.address, 50, {from: accounts[2]});
    await adversaryInstance.createOffer(true, 'ethusd', 10, {from: accounts[0]});
    await adversaryInstance.createOffer(true, 'ethusd', 10, {from: accounts[0]});
    await adversaryInstance.createOffer(true, 'ethbtc', 10, {from: accounts[0]});
    await adversaryInstance.createOffer(true, 'ethusd', 10, {from: accounts[1]});
    await adversaryInstance.createOffer(false, 'ethusd', 10, {from: accounts[1]});
    await adversaryInstance.createOffer(false, 'ethusd', 10, {from: accounts[2]});

    assert.equal(await fakeDaiInstance.balanceOf.call(adversaryInstance.address), 60);
    assert.equal(await fakeDaiInstance.balanceOf.call(accounts[0]), 770);
    assert.equal(await fakeDaiInstance.balanceOf.call(accounts[1]), 80);
    assert.equal(await fakeDaiInstance.balanceOf.call(accounts[2]), 90);

    var numOffers = await adversaryInstance.getNumOffers.call();
    var i;
    var existingIds = [];
    for (i = 0; i < numOffers; i++) {
      existingIds.push(await adversaryInstance.offerIds.call(i));
    }
    for (i = 0; i < numOffers; i++) {
      let offer = await adversaryInstance.offers.call(existingIds[i]);
      if (offer[offerMakerIndex].toString() == accounts[1].toLowerCase()) {
        await adversaryInstance.deleteOffer(existingIds[i], {from: accounts[1]});
        let newNumOffers = await adversaryInstance.getNumOffers.call();
      }
    }
    numOffers = await adversaryInstance.getNumOffers.call();
    assert.equal(numOffers, 4);
    await adversaryInstance.createOffer(true, 'ethusd', 10, {from: accounts[2]});
    numOffers = await adversaryInstance.getNumOffers.call();
    assert.equal(numOffers, 5);

    // Make sure shuffling has worked
    existingIds = [];
    for (i = 0; i < numOffers; i++) {
      let id = await adversaryInstance.offerIds.call(i);
      existingIds.push(id);
    }
    for (i = 0; i < numOffers; i++) {
      let offer = await adversaryInstance.offers.call(existingIds[i]);
      assert.isAbove(offer[offerDaiIndex], 0);
    }

    assert.equal(await fakeDaiInstance.balanceOf.call(adversaryInstance.address), 50);
    assert.equal(await fakeDaiInstance.balanceOf.call(accounts[0]), 770);
    assert.equal(await fakeDaiInstance.balanceOf.call(accounts[1]), 100);
    assert.equal(await fakeDaiInstance.balanceOf.call(accounts[2]), 80);
  });

  it("Create escrows", async function() {
    this.timeout(35 * 1000);
    var numEscrows = 0;
    //take up the first offer made by account zero with account[3] which still has 30 dai approved
    let id = await adversaryInstance.offerIds.call(0);
    const NewEscrow = adversaryInstance.NewEscrow();
    // send ether to contract so it can pay oracle
    let ethForOracle = await adversaryInstance.getEthRequiredForEscrow.call();
    ethForOracle = ethForOracle.toNumber();
    await adversaryInstance.send(ethForOracle, {from: accounts[2]});
    await adversaryInstance.createEscrow(id, {from: accounts[2]});
    let checkForPrice = new Promise((resolve, reject)  => {
      NewEscrow.watch(async function(error, result) {
        if (error) {
          reject(error);
        }
        numEscrows = await adversaryInstance.getNumEscrows();
        NewEscrow.stopWatching();
        resolve(numEscrows);
      });
    });
    const resultNumEscrows = await checkForPrice;
    assert.equal(numEscrows, 1);
  });

  it("Claim escrow", async function() {
    this.timeout(35 * 1000);
    //take up the only escrow as maker, account[0]. Taker is acount[2]
    let id = await adversaryInstance.escrowIds.call(0);
    var numEscrows = 1;
    var account0DaiBefore = await fakeDaiInstance.balanceOf.call(accounts[0]);
    var account2DaiBefore = await fakeDaiInstance.balanceOf.call(accounts[2]);
    let escrow = await adversaryInstance.escrows.call(id);
    var escrowDai = escrow[escrowDaiIndex];
    console.log("a0b is ", account0DaiBefore, ' a0btn = ', account0DaiBefore.toNumber(), " ed is ", escrowDai);
    var sumBefore = account0DaiBefore.toNumber() + account2DaiBefore.toNumber() + escrowDai.toNumber();

    const TradeCompleted = adversaryInstance.TradeCompleted();
    // send ether to contract so it can pay oracle
    let ethForOracle = await adversaryInstance.getEthRequiredForClaim.call();
    ethForOracle = ethForOracle.toNumber();
    await adversaryInstance.send(ethForOracle, {from: accounts[0]});
    await adversaryInstance.claimEscrow(id, {from: accounts[2]});
    let checkForPrice = new Promise((resolve, reject)  => {
      TradeCompleted.watch(async function(error, result) {
        if (error) {
          reject(error);
        }
        numEscrows = await adversaryInstance.getNumEscrows();
        TradeCompleted.stopWatching();
        resolve(numEscrows);
      });
    });
    const resultNumEscrows = await checkForPrice;
    var account0DaiAfter = await fakeDaiInstance.balanceOf.call(accounts[0]);
    var account2DaiAfter = await fakeDaiInstance.balanceOf.call(accounts[2]);
    var sumAfter = account0DaiAfter.toNumber() + account2DaiAfter.toNumber();
    assert.equal(sumBefore, sumAfter);
    assert.equal(numEscrows, 0);
  });
});

// TODO allow termination when price above x or below y, heaviside.
// TODO test required failures like txs from wrong addresses etc.
