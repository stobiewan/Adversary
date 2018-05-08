pragma solidity ^0.4.23;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../../contracts/Adversary.sol";

contract TestAdversary {

  function testOfferCreation() public {
    Adversary adversary = Adversary(DeployedAddresses.Adversary());

    uint expected = 0;

    Assert.equal(0, expected, "stuff");
    /* Assert.equal(meta.getBalance(tx.origin), expected, "Owner should have 10000 MetaCoin initially"); */
  }
/*
  function testInitialBalanceWithNewMetaCoin() public {
    MetaCoin meta = new MetaCoin();

    uint expected = 10000;

    Assert.equal(meta.getBalance(tx.origin), expected, "Owner should have 10000 MetaCoin initially");
  } */

}
