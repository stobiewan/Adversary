pragma solidity ^0.4.23;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../../contracts/Adversary.sol";

contract TestAdversary {

  function testRewardCalculation() public {
    Adversary adversary = Adversary(DeployedAddresses.Adversary());

    uint ceilingCents = 10000;
    uint floorCents = 10000;
    uint daiInEscrow = 200 * 10 ** 18;
    uint startPriceCents = 10000;
    bool makerIsLong = true;
    string memory priceResult = "125.00";
    uint payoutForMaker = 0;
    uint payoutForTaker = 0;
    (payoutForMaker, payoutForTaker) = adversary.calculateReturns(ceilingCents, floorCents, daiInEscrow,
                                                                  startPriceCents, makerIsLong, priceResult);
    Assert.equal(150 * 10 ** 18, payoutForMaker, "payout for maker was incorrect");
    Assert.equal(50 * 10 ** 18, payoutForTaker, "payout for taker was incorrect");
  }
}
