var Users = artifacts.require("./Users.sol");
var fakeDai = artifacts.require("./DSToken");
var adversary = artifacts.require("./Adversary");

const asyncSetup = async function asyncSetup() {
  var account_one = "0xEEb19ed20b616b1039Ebf12ae781052007f6e5cF";
  var account_two = "0x8f0bd175C2E4eeC7924177dF3ecE1A89D77a755C";
  var account_three = "0x7E93b2A71442a323BA0BB40a2337c9Cdcd69E843";
  adversaryInstance = await adversary.deployed();
  fakeDaiInstance = await fakeDai.deployed();
  var result = await adversaryInstance.setDaiContractAddress(fakeDaiInstance.address);
  result = await fakeDaiInstance.mint(1000, {from: account_one});
  result = await fakeDaiInstance.push(account_two, 100, {from: account_one});
  result = await fakeDaiInstance.push(account_three, 100, {from: account_one});
}

module.exports = function(deployer) {
  deployer.deploy(Users);
  deployer.deploy(fakeDai, "FakeDai");
  deployer.deploy(adversary);
  deployer.then(async() => await asyncSetup())
};
