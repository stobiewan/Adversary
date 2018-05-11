const Adversary = artifacts.require("Adversary");
const DSToken = artifacts.require("DSToken");

contract('Offers test', async (accounts) => {

  var adversaryInstance;
  var fakeDaiInstance;
  const offerMakerIndex = 0;
  const offerDaiIndex = 3;

  it("mint fake Dai and distribute", async () => {
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
    result = await fakeDaiInstance.approve(adversaryInstance.address, 50, {from: accounts[0]});
    result = await fakeDaiInstance.approve(adversaryInstance.address, 50, {from: accounts[1]});
    result = await fakeDaiInstance.approve(adversaryInstance.address, 50, {from: accounts[2]});
    result = await adversaryInstance.createOffer(true, 'ethusd', 10, {from: accounts[0]});
    result = await adversaryInstance.createOffer(true, 'ethusd', 10, {from: accounts[0]});
    result = await adversaryInstance.createOffer(true, 'ethbtc', 10, {from: accounts[0]});
    result = await adversaryInstance.createOffer(true, 'ethusd', 10, {from: accounts[1]});
    result = await adversaryInstance.createOffer(false, 'ethusd', 10, {from: accounts[1]});
    result = await adversaryInstance.createOffer(false, 'ethusd', 10, {from: accounts[2]});

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
        result = await adversaryInstance.deleteOffer(existingIds[i], {from: accounts[1]});
        let newNumOffers = await adversaryInstance.getNumOffers.call();
      }
    }
    numOffers = await adversaryInstance.getNumOffers.call();
    assert.equal(numOffers, 4);
    result = await adversaryInstance.createOffer(true, 'ethusd', 10, {from: accounts[2]});
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
});

// TODO allow termination to be price above or below after date etc
// TODO test required failures like txs from wrong addresses etc.
