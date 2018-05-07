var Users = artifacts.require("./Users.sol");
var fakeDai = artifacts.require("./DSToken");
var adversary = artifacts.require("./Adversary");

module.exports = function(deployer) {
  deployer.deploy(Users);
  deployer.deploy(fakeDai, "FakeDai");
  deployer.deploy(adversary);
};
