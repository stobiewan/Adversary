const Adversary = artifacts.require("Adversary");
const DSToken = artifacts.require("DSToken");

contract('Offers test', async (offers) => {

  var account_one = "0xEEb19ed20b616b1039Ebf12ae781052007f6e5cF";
  var account_two = "0x8f0bd175C2E4eeC7924177dF3ecE1A89D77a755C";
  var account_three = "0x7E93b2A71442a323BA0BB40a2337c9Cdcd69E843";
  var adversaryInstance;
  var fakeDaiInstance;
  const offerMakerIndex = 0;
  const offerDaiIndex = 3;

  it("mint fake Dai and distribute", async () => {
     adversaryInstance = await Adversary.deployed();
     fakeDaiInstance = await DSToken.deployed();
     let accountOneDai = await fakeDaiInstance.balanceOf.call(account_one);
     let accountTwoDai = await fakeDaiInstance.balanceOf.call(account_two);
     let accountThreeDai = await fakeDaiInstance.balanceOf.call(account_three);
     assert.equal(accountOneDai, 800);
     assert.equal(accountTwoDai, 100);
     assert.equal(accountThreeDai, 100);
  });

  it("create offers and test dai", async () => {
    result = await fakeDaiInstance.approve(adversaryInstance.address, 50, {from: account_one});
    result = await fakeDaiInstance.approve(adversaryInstance.address, 50, {from: account_two});
    result = await fakeDaiInstance.approve(adversaryInstance.address, 50, {from: account_three});
    result = await adversaryInstance.createOffer(true, 'ethusd', 10, {from: account_one});
    result = await adversaryInstance.createOffer(true, 'ethusd', 10, {from: account_one});
    result = await adversaryInstance.createOffer(true, 'ethbtc', 10, {from: account_one});
    result = await adversaryInstance.createOffer(true, 'ethusd', 10, {from: account_two});
    result = await adversaryInstance.createOffer(false, 'ethusd', 10, {from: account_two});
    result = await adversaryInstance.createOffer(false, 'ethusd', 10, {from: account_three});

    assert.equal(await fakeDaiInstance.balanceOf.call(adversaryInstance.address), 60);
    assert.equal(await fakeDaiInstance.balanceOf.call(account_one), 770);
    assert.equal(await fakeDaiInstance.balanceOf.call(account_two), 80);
    assert.equal(await fakeDaiInstance.balanceOf.call(account_three), 90);

    var numOffers = await adversaryInstance.getNumOffers.call();
    var i;
    var existingIds = [];
    for (i = 0; i < numOffers; i++) {
      existingIds.push(await adversaryInstance.offerIds.call(i));
    }
    for (i = 0; i < numOffers; i++) {
      let offer = await adversaryInstance.offers.call(existingIds[i]);
      if (offer[offerMakerIndex].toString() == account_two.toLowerCase()) {
        result = await adversaryInstance.deleteOffer(existingIds[i], {from: account_two});
        let newNumOffers = await adversaryInstance.getNumOffers.call();
      }
    }
    numOffers = await adversaryInstance.getNumOffers.call();
    assert.equal(numOffers, 4);
    result = await adversaryInstance.createOffer(true, 'ethusd', 10, {from: account_three});
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
    assert.equal(await fakeDaiInstance.balanceOf.call(account_one), 770);
    assert.equal(await fakeDaiInstance.balanceOf.call(account_two), 100);
    assert.equal(await fakeDaiInstance.balanceOf.call(account_three), 80);

  });
});

// TODO allow termination to be price above or below after date etc
// TODO test required failures like txs from wrong addresses etc.
