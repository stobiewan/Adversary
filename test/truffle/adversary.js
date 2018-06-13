const Adversary = artifacts.require("Adversary");
const DSToken = artifacts.require("DSToken");
const oneDai = Math.pow(10, 18);
const floatingError = Math.pow(10, 12);  // EVM uint256 can't be converted into js numbers without precision loss.
const offerMakerIndex = 0;
const offerTakerIndex = 1;
const offerDaiIndex = 3;
const escrowDaiIndex = 4;

contract('Offers test', async (accounts) => {

  var adversaryInstance;
  var fakeDaiInstance;

  function bigNumToDai(bigNum) {
    return bigNum.toNumber() / oneDai;
  }

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
    await fakeDaiInstance.approve(adversaryInstance.address, 50 * oneDai, {from: accounts[0]});
    await fakeDaiInstance.approve(adversaryInstance.address, 50 * oneDai, {from: accounts[1]});
    await fakeDaiInstance.approve(adversaryInstance.address, 50 * oneDai, {from: accounts[2]});
    await fakeDaiInstance.approve(adversaryInstance.address, 50 * oneDai, {from: accounts[3]});
    await adversaryInstance.createOffer(true, 'ETHUSD', 10 * oneDai, 2, 0, 0, 0, {from: accounts[0]});
    await adversaryInstance.createOffer(true, 'ETHUSD', 10 * oneDai, 2, 0, 0, 0, {from: accounts[0]});
    await adversaryInstance.createOffer(true, 'ETHBTC', 10 * oneDai, 2, 0, 0, 0, {from: accounts[0]});
    await adversaryInstance.createOffer(true, 'ETHUSD', 10 * oneDai, 2, 0, 0, 0, {from: accounts[1]});
    await adversaryInstance.createOffer(false, 'ETHUSD', 10 * oneDai,2,  0, 0, 0, {from: accounts[1]});
    await adversaryInstance.createOffer(false, 'ETHUSD', 10 * oneDai,2,  0, 0, 0, {from: accounts[2]});

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
    await adversaryInstance.createOffer(true, 'ETHUSD', 10 * oneDai, 2, 0, 0, 0, {from: accounts[2]});
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

  async function createEscrow(id, fromAccount, escrowCreationGas) {
    var gasPriceToUse = 20000000000;
    var ethForOracle = escrowCreationGas * gasPriceToUse + Math.pow(10, 15);
    const NewEscrow = adversaryInstance.NewEscrow();
    await adversaryInstance.createEscrow(id, {value: ethForOracle, from: accounts[fromAccount], gasPrice: gasPriceToUse});
    // watch for NewEscrow event. Need to wait until oracle calls __callback.
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
    return numEscrows;
  }

  it("Create escrows", async function() {
    this.timeout(40 * 1000);
    var numEscrows = 0;
    var escrowCreationGas = await adversaryInstance.CREATE_ESCROW_GAS_LIMIT.call();
    let offerId0 = await adversaryInstance.offerIds.call(0);
    let offerId1 = await adversaryInstance.offerIds.call(1);
    let offerId2 = await adversaryInstance.offerIds.call(2);
    let offerId3 = await adversaryInstance.offerIds.call(3);
    //take up the first offer made by account zero with account[2] which still has 30 dai approved
    await createEscrow(offerId0, 2, escrowCreationGas);
    await createEscrow(offerId2, 3, escrowCreationGas);
    await createEscrow(offerId1, 3, escrowCreationGas);
    numEscrows = await createEscrow(offerId3, 3, escrowCreationGas);
    assert.equal(numEscrows, 4);
  });

  it("Check dai can be wihdrawn without stealing", async function() {
    //The contract should initially contain 90 dai, with 80 spread accross 4 escrows.
    var initialDaiInContract = await fakeDaiInstance.balanceOf.call(adversaryInstance.address);
    assert.equal(initialDaiInContract, 90 * oneDai);
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
    // Only the owner (account0) should be able to withdraw so account2's balance should be the same.
    var account2DaiAfter = await fakeDaiInstance.balanceOf.call(accounts[2]);
    assert.equal(account2DaiBefore.toNumber(), account2DaiAfter);

    await adversaryInstance.withdrawDai({from: accounts[0]});
    var account0DaiAfter = await fakeDaiInstance.balanceOf.call(accounts[0]);
    var contractDai = await fakeDaiInstance.balanceOf.call(adversaryInstance.address);
    // 80 dai went into an escrow so 0.4 should be claimed in fees.
    var expectedContractDai = initialDaiInContract - 0.4 * oneDai;
    assert.equal(contractDai.toNumber(), expectedContractDai);
    // account0 had 770 dai before withdrawing so should now have another 0.4
    assert.equal(account0DaiAfter.toNumber(), 770.4 * oneDai);
  });

  async function assertExpectedEscrows(expectedIds) {
    expectedLen = expectedIds.length;
    let numEscrows = await adversaryInstance.getNumEscrows();
    assert.equal(numEscrows, expectedLen);
    var i;
    for (i = 0; i < expectedLen; i++) {
        let id = await adversaryInstance.escrowIds.call(i);
        assert.equal(id.toNumber(), expectedIds[i]);
    }
  }

  function toHex(str) {
    var hex = ''
    for(var i = 0; i < str.length; i++) {
      hex += '' + str.charCodeAt(i).toString(16)
    }
    return hex
  }

  function splitSignature(signature) {
    signature = signature.substr(2); //remove 0x
    const r = '0x' + signature.slice(0, 64);
    const s = '0x' + signature.slice(64, 128);
    const v = '0x' + signature.slice(128, 130);
    const v_decimal = web3.toDecimal(v);
    return [r, s, v_decimal];
  }

  it("Rescue stuck escrows", async function() {
    // see https://medium.com/@angellopozo/ethereum-signing-and-validating-13a2d7cb0ee3
    await assertExpectedEscrows([8, 9, 10, 11]);
    let escrow = await adversaryInstance.escrows.call(9);
    var makerAddress = escrow[offerMakerIndex];
    var takerAddress = escrow[offerTakerIndex];
    var wrongAddress = accounts[9];
    var message = 'sign to destroy escrow';
    // expect messages to be signed with geth which prepends a bit to the start
    var fixed_msg = `\x19Ethereum Signed Message:\n${message.length}${message}`;
    var fixed_msg_sha = web3.sha3(fixed_msg);
    var makerSignature = web3.eth.sign(makerAddress, '0x' + toHex(message));
    var takerSignature = web3.eth.sign(takerAddress, '0x' + toHex(message));
    var wrongSignature = web3.eth.sign(wrongAddress, '0x' + toHex(message));
    var mr, ms, mv_decimal;
    var tr, ts, tv_decimal;
    var wr, ws, wv_decimal;
    [mr, ms, mv_decimal] = splitSignature(makerSignature);
    [tr, ts, tv_decimal] = splitSignature(takerSignature);
    [wr, ws, wv_decimal] = splitSignature(wrongSignature);
    mv_decimal += 27;
    tv_decimal += 27;
    wv_decimal += 27;
    var expectedError = false;
    try{
      // try to destroy escrow with wrong elliptic curve variables, make sure it reverts
      await adversaryInstance.rescueStuckEscrow(9, mv_decimal, mr, ms, wv_decimal, wr, ws);
    }
    catch(err){
      expectedError = true;
    }
    if (!expectedError){
      throw "escrow cancelled without permission";
    }
    await adversaryInstance.rescueStuckEscrow(9, mv_decimal, mr, ms, tv_decimal, tr, ts);
    await assertExpectedEscrows([8, 11, 10]);
  });

  async function claimEscrow(id, fromAccount, escrowClaimGas) {
    var gasPriceToUse = 20000000000;
    var ethForOracle = escrowClaimGas * gasPriceToUse + Math.pow(10, 15);
    const TradeCompleted = adversaryInstance.TradeCompleted();
    await adversaryInstance.claimEscrow(id, {value: ethForOracle, from: accounts[fromAccount], gasPrice: gasPriceToUse});
    // watch for TradeCompleted event. Need to wait until oracle calls __callback.
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
  }

  it("Claim escrow", async function() {
    /* existing escrows are:
      id = 8, maker = 0, taker = 2, eth 19.9
      id = 11, maker = 2, taker = 3, eth 19.9
      id = 10, maker = 0, taker = 3, eth 19.9
    */
    var numEscrows;
    this.timeout(40 * 1000);
    await assertExpectedEscrows([8, 11, 10]);
    var escrowClaimGas = await adversaryInstance.CLAIM_ESCROW_GAS_LIMIT.call();
    var account0DaiBefore = await fakeDaiInstance.balanceOf.call(accounts[0]);
    var account2DaiBefore = await fakeDaiInstance.balanceOf.call(accounts[2]);
    var account3DaiBefore = await fakeDaiInstance.balanceOf.call(accounts[3]);
    let escrow = await adversaryInstance.escrows.call(8);
    var escrowDai = escrow[escrowDaiIndex];
    var sumBefore = bigNumToDai(account0DaiBefore) + bigNumToDai(account2DaiBefore) + bigNumToDai(escrowDai);

    // // try to claim escrow from wrong account, when uncommented this should timeout watching for TradeComplete event
    // await claimEscrow(8, 9, escrowClaimGas);

    await claimEscrow(8, 2, escrowClaimGas);
    var account0DaiAfter = await fakeDaiInstance.balanceOf.call(accounts[0]);
    var account2DaiAfter = await fakeDaiInstance.balanceOf.call(accounts[2]);
    account0DaiAfter = bigNumToDai(account0DaiAfter);
    account2DaiAfter = bigNumToDai(account2DaiAfter);
    var sumAfter = account0DaiAfter + account2DaiAfter;
    var error = Math.abs(sumAfter - sumBefore);
    assert(error < floatingError);
    await assertExpectedEscrows([10, 11]);
    // // These can be uncommented to test emptying all escrows
    // await claimEscrow(11, 3, escrowClaimGas);
    // await assertExpectedEscrows([10]);
    // await claimEscrow(10, 0, escrowClaimGas);
    // await assertExpectedEscrows([]);
  });
});

/* TODO: lock period escrowIds
*/
