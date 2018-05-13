var Users = artifacts.require("./Users.sol");
var fakeDai = artifacts.require("./DSToken");
var adversary = artifacts.require("./Adversary");


const asyncSetup = async function asyncSetup(accounts) {
  adversaryInstance = await adversary.deployed();
  fakeDaiInstance = await fakeDai.deployed();
  await adversaryInstance.setDaiContractAddress(fakeDaiInstance.address);
  await fakeDaiInstance.mint(1000, {from: accounts[0]});
  await fakeDaiInstance.push(accounts[1], 100, {from: accounts[0]});
  await fakeDaiInstance.push(accounts[2], 100, {from: accounts[0]});
  // await adversaryInstance.setOracleResponseGasPrice(1000000000, {from: accounts[0]});
}


module.exports = function(deployer, network, accounts) {
  if(network == 'development'){
    deployer.deploy(Users);
    deployer.deploy(fakeDai, "FakeDai");
    deployer.deploy(adversary);
    deployer.then(async() => await asyncSetup(accounts))
  }
  else if(network == "rinkeby"){
    deployer.deploy(fakeDai, "FakeDai");
    deployer.deploy(adversary);
    deployer.then(async() => await asyncSetup())
  }
  else if (network == "live") {
    deployer.deploy(adversary);
  }
};
