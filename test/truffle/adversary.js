const Adversary = artifacts.require("Adversary");
const DSToken = artifacts.require("DSToken");
const oneDai = Math.pow(10, 18);

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
     assert.equal(accountOneDai, 800 * oneDai);
     assert.equal(accountTwoDai, 100 * oneDai);
     assert.equal(accountThreeDai, 100 * oneDai);
  });

  it("create offers and test dai", async () => {
    await fakeDaiInstance.approve(adversaryInstance.address, 50 * oneDai, {from: accounts[1]});
    await fakeDaiInstance.approve(adversaryInstance.address, 50 * oneDai, {from: accounts[0]});
    await fakeDaiInstance.approve(adversaryInstance.address, 50 * oneDai, {from: accounts[2]});
    await adversaryInstance.createOffer(true, 'ethusd', 10 * oneDai, 2, 0, 0, 0, {from: accounts[0]});
    await adversaryInstance.createOffer(true, 'ethusd', 10 * oneDai, 2, 0, 0, 0, {from: accounts[0]});
    await adversaryInstance.createOffer(true, 'ethbtc', 10 * oneDai, 2, 0, 0, 0, {from: accounts[0]});
    await adversaryInstance.createOffer(true, 'ethusd', 10 * oneDai, 2, 0, 0, 0, {from: accounts[1]});
    await adversaryInstance.createOffer(false, 'ethusd', 10 * oneDai,2,  0, 0, 0, {from: accounts[1]});
    await adversaryInstance.createOffer(false, 'ethusd', 10 * oneDai,2,  0, 0, 0, {from: accounts[2]});

    assert.equal(await fakeDaiInstance.balanceOf.call(adversaryInstance.address), 60 * oneDai);
    assert.equal(await fakeDaiInstance.balanceOf.call(accounts[0]), 770 * oneDai);
    assert.equal(await fakeDaiInstance.balanceOf.call(accounts[1]), 80 * oneDai);
    assert.equal(await fakeDaiInstance.balanceOf.call(accounts[2]), 90 * oneDai);

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
    await adversaryInstance.createOffer(true, 'ethusd', 10 * oneDai, 2, 0, 0, 0, {from: accounts[2]});
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
    assert.equal(await fakeDaiInstance.balanceOf.call(adversaryInstance.address), 50 * oneDai);
    assert.equal(await fakeDaiInstance.balanceOf.call(accounts[0]), 770 * oneDai);
    assert.equal(await fakeDaiInstance.balanceOf.call(accounts[1]), 100 * oneDai);
    assert.equal(await fakeDaiInstance.balanceOf.call(accounts[2]), 80 * oneDai);
  });

  it("Create escrows", async function() {
    this.timeout(35 * 1000);
    var numEscrows = 0;
    var escrowCreationGas = await adversaryInstance.createEscrowGasLimit.call();
    var gasPriceToUse = 20000000000;
    var ethForOracle = escrowCreationGas * gasPriceToUse + Math.pow(10, 15);
    //take up the first offer made by account zero with account[3] which still has 30 dai approved
    let id = await adversaryInstance.offerIds.call(0);
    const NewEscrow = adversaryInstance.NewEscrow();
    await adversaryInstance.createEscrow(id, {value: ethForOracle, from: accounts[2], gasPrice: gasPriceToUse});
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

  it("Check dai can be wihdrawn without stealing", async function() {
    //There should initially be 60 dai within the escrow, and 20 has gone into escrow.
    assert.equal(await fakeDaiInstance.balanceOf.call(adversaryInstance.address), 60 * oneDai);
    var account0DaiBefore = await fakeDaiInstance.balanceOf.call(accounts[0]);
    var account2DaiBefore = await fakeDaiInstance.balanceOf.call(accounts[2]);
    var expectedError = false;
    try{
      await adversaryInstance.withdrawDai({from: accounts[2]});
    }
    catch(err){
      expectedError = true;
    }
    if (!expectedError){
      throw "user stole dai";
    }
    var account2DaiAfter = await fakeDaiInstance.balanceOf.call(accounts[2]);
    // Only the owner (account0) should be able to withdraw so account2's balance should be the same.
    await adversaryInstance.withdrawDai({from: accounts[0]});
    var account0DaiAfter = await fakeDaiInstance.balanceOf.call(accounts[0]);
    var contractDai = await fakeDaiInstance.balanceOf.call(adversaryInstance.address);
    // 20 dai went into an escrow so 0.1 should be claimed in fees.
    var expectedContractDai = 59.9 * oneDai
    assert.equal(contractDai.toNumber(), expectedContractDai);
    // account0 had 770 dai before withdrawing so should now have another 0.1
    assert.equal(account0DaiAfter.toNumber(), 770.1 * oneDai);
  });

  it("Claim escrow", async function() {
    this.timeout(35 * 1000);
    var escrowClaimGas = await adversaryInstance.claimEscrowGasLimit.call();
    var gasPriceToUse = 20000000000;
    var ethForOracle = escrowClaimGas * gasPriceToUse + Math.pow(10, 15);
    //take up the only escrow as maker, account[0]. Taker is acount[2]
    let id = await adversaryInstance.escrowIds.call(0);
    var numEscrows = 1;
    var account0DaiBefore = await fakeDaiInstance.balanceOf.call(accounts[0]);
    var account2DaiBefore = await fakeDaiInstance.balanceOf.call(accounts[2]);
    let escrow = await adversaryInstance.escrows.call(id);
    var escrowDai = escrow[escrowDaiIndex];
    var sumBefore = account0DaiBefore.toNumber() + account2DaiBefore.toNumber() + escrowDai.toNumber();

    const TradeCompleted = adversaryInstance.TradeCompleted();
    await adversaryInstance.claimEscrow(id, {value: ethForOracle, from: accounts[2], gasPrice: gasPriceToUse});
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

/* TODO: Test required failures like txs from wrong addresses, step reward claim inside bounds, etc
         out of order escrow claims,
         lock period escrowIds
         eth and dai withdrawals when some are held in offers and escrows.
*/
