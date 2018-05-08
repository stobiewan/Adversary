var Users = artifacts.require("./Users.sol");
var fakeDai = artifacts.require("./DSToken");
var adversary = artifacts.require("./Adversary");

module.exports = function(deployer, network) {
  if(network == 'development'){
    deployer.deploy(Users);
    deployer.deploy(fakeDai, "FakeDai");
    deployer.deploy(adversary);
  }
  else if(network == "rinkeby"){
    deployer.deploy(fakeDai, "FakeDai");
    deployer.deploy(adversary);
  }
  else if (network == "live") {
    deployer.deploy(adversary);
  }
};
