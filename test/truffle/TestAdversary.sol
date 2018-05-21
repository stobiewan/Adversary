pragma solidity ^0.4.23;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../../contracts/Adversary.sol";

contract TestAdversary {

  function testRewardCalculationIncrease1() public {
    Adversary adversary = Adversary(DeployedAddresses.Adversary());
    uint margin = 2;
    uint ceilingCents = 10000;
    uint floorCents = 10000;
    uint daiInEscrow = 200 * 10 ** 18;
    uint startPriceCents = 10000;
    bool makerIsLong = true;
    string memory priceResult = "125.00";
    uint payoutForMaker = 0;
    uint payoutForTaker = 0;
    (payoutForMaker, payoutForTaker) = adversary.calculateReturns(margin, ceilingCents, floorCents, daiInEscrow,
                                                                  startPriceCents, makerIsLong, priceResult);
    Assert.equal(150 * 10 ** 18, payoutForMaker, "payout for maker was incorrect");
    Assert.equal(50 * 10 ** 18, payoutForTaker, "payout for taker was incorrect");
  }

  function testRewardCalculationIncrease2() public {
    Adversary adversary = Adversary(DeployedAddresses.Adversary());
    uint margin = 3;
    uint ceilingCents = 10000;
    uint floorCents = 10000;
    uint daiInEscrow = 200 * 10 ** 18;
    uint startPriceCents = 10000;
    bool makerIsLong = true;
    string memory priceResult = "120.00";
    uint payoutForMaker = 0;
    uint payoutForTaker = 0;
    (payoutForMaker, payoutForTaker) = adversary.calculateReturns(margin, ceilingCents, floorCents, daiInEscrow,
                                                                  startPriceCents, makerIsLong, priceResult);
    Assert.equal(160 * 10 ** 18, payoutForMaker, "payout for maker was incorrect");
    Assert.equal(40 * 10 ** 18, payoutForTaker, "payout for taker was incorrect");
  }

  function testRewardCalculationIncrease3() public {
    Adversary adversary = Adversary(DeployedAddresses.Adversary());
    uint margin = 4;
    uint ceilingCents = 10000;
    uint floorCents = 10000;
    uint daiInEscrow = 200 * 10 ** 18;
    uint startPriceCents = 10000;
    bool makerIsLong = true;
    string memory priceResult = "130.00";
    uint payoutForMaker = 0;
    uint payoutForTaker = 0;
    (payoutForMaker, payoutForTaker) = adversary.calculateReturns(margin, ceilingCents, floorCents, daiInEscrow,
                                                                  startPriceCents, makerIsLong, priceResult);
    Assert.equal(200 * 10 ** 18, payoutForMaker, "payout for maker was incorrect");
    Assert.equal(0 * 10 ** 18, payoutForTaker, "payout for taker was incorrect");
  }

  function testRewardCalculationDecrease1() public {
    Adversary adversary = Adversary(DeployedAddresses.Adversary());
    uint margin = 2;
    uint ceilingCents = 10000;
    uint floorCents = 10000;
    uint daiInEscrow = 200 * 10 ** 18;
    uint startPriceCents = 10000;
    bool makerIsLong = true;
    string memory priceResult = "75.00";
    uint payoutForMaker = 0;
    uint payoutForTaker = 0;
    (payoutForMaker, payoutForTaker) = adversary.calculateReturns(margin, ceilingCents, floorCents, daiInEscrow,
                                                                  startPriceCents, makerIsLong, priceResult);
    Assert.equal(50 * 10 ** 18, payoutForMaker, "payout for maker was incorrect");
    Assert.equal(150 * 10 ** 18, payoutForTaker, "payout for taker was incorrect");
  }

  function testRewardCalculationDecrease2() public {
    Adversary adversary = Adversary(DeployedAddresses.Adversary());
    uint margin = 4;
    uint ceilingCents = 10000;
    uint floorCents = 10000;
    uint daiInEscrow = 200 * 10 ** 18;
    uint startPriceCents = 10000;
    bool makerIsLong = true;
    string memory priceResult = "75.00";
    uint payoutForMaker = 0;
    uint payoutForTaker = 0;
    (payoutForMaker, payoutForTaker) = adversary.calculateReturns(margin, ceilingCents, floorCents, daiInEscrow,
                                                                  startPriceCents, makerIsLong, priceResult);
    Assert.equal(0 * 10 ** 18, payoutForMaker, "payout for maker was incorrect");
    Assert.equal(200 * 10 ** 18, payoutForTaker, "payout for taker was incorrect");
  }

  function testRewardCalculationDecrease3() public {
    Adversary adversary = Adversary(DeployedAddresses.Adversary());
    uint margin = 10;
    uint ceilingCents = 10000;
    uint floorCents = 10000;
    uint daiInEscrow = 200 * 10 ** 18;
    uint startPriceCents = 10000;
    bool makerIsLong = true;
    string memory priceResult = "75.00";
    uint payoutForMaker = 0;
    uint payoutForTaker = 0;
    (payoutForMaker, payoutForTaker) = adversary.calculateReturns(margin, ceilingCents, floorCents, daiInEscrow,
                                                                  startPriceCents, makerIsLong, priceResult);
    Assert.equal(0 * 10 ** 18, payoutForMaker, "payout for maker was incorrect");
    Assert.equal(200 * 10 ** 18, payoutForTaker, "payout for taker was incorrect");
  }

  function testRewardCalculationLongStep() public {
    Adversary adversary = Adversary(DeployedAddresses.Adversary());
    uint margin = 2;
    uint ceilingCents = 10500;
    uint floorCents = 9500;
    uint daiInEscrow = 200 * 10 ** 18;
    uint startPriceCents = 10000;
    bool makerIsLong = true;
    string memory priceResult = "106.00";
    uint payoutForMaker = 0;
    uint payoutForTaker = 0;
    (payoutForMaker, payoutForTaker) = adversary.calculateReturns(margin, ceilingCents, floorCents, daiInEscrow,
                                                                  startPriceCents, makerIsLong, priceResult);
    Assert.equal(200 * 10 ** 18, payoutForMaker, "payout for maker was incorrect");
    Assert.equal(0 * 10 ** 18, payoutForTaker, "payout for taker was incorrect");
  }

  function testRewardCalculationShortStep() public {
    Adversary adversary = Adversary(DeployedAddresses.Adversary());
    uint margin = 2;
    uint ceilingCents = 10500;
    uint floorCents = 9500;
    uint daiInEscrow = 200 * 10 ** 18;
    uint startPriceCents = 10000;
    bool makerIsLong = true;
    string memory priceResult = "94.00";
    uint payoutForMaker = 0;
    uint payoutForTaker = 0;
    (payoutForMaker, payoutForTaker) = adversary.calculateReturns(margin, ceilingCents, floorCents, daiInEscrow,
                                                                  startPriceCents, makerIsLong, priceResult);
    Assert.equal(0 * 10 ** 18, payoutForMaker, "payout for maker was incorrect");
    Assert.equal(200 * 10 ** 18, payoutForTaker, "payout for taker was incorrect");
  }

  // TODO test inside step limits, on limits, outside proportional limits
}
