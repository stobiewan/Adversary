pragma solidity ^0.4.23;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./DaiInterface.sol";
import "./oraclizeAPI_0_5.sol";

contract Adversary is DaiTransferrer, usingOraclize {

  using SafeMath for uint256;

  event NewOffer();
  event OfferDeleted();
  event NewEscrow();
  event TradeCompleted();
  event LogPriceUpdated(string price);
  event LogNewOraclizeQuery(string description);

  struct Offer {
    address maker;
    bool makerIsLong;
    string currency;
    uint dai;
    uint listIndex;
    uint margin;
    uint positiveDeltaCents;
    uint negativeDeltaCents;
  }

  struct PendingTake {
    address taker;
    uint64 offerId;
  }

  struct PendingClaim {
    address claimer;
    uint64 escrowId;
  }

  struct Escrow {
    address maker;
    address taker;
    bool makerIsLong;
    string currency;
    uint dai;
    uint listIndex;
    uint startPriceCents;
    uint margin;
    uint ceilingCents;
    uint floorCents;
  }

  uint public oneDai = 10 ** 18;
  uint public minimumDai = 10 * oneDai;
  uint public createEscrowGasLimit = 400000;  // TODO set once code is finalised
  uint public claimEscrowGasLimit = 400000;  // TODO calculate in testing
  uint public oracleGasPrice = 20000000000;
  uint64[] public offerIds;
  uint64[] public escrowIds;
  uint64 public currentId = 1;

  mapping (uint64 => Offer) public offers;
  mapping (uint64 => Escrow) public escrows;
  mapping (bytes32 => PendingTake) public pendingTakes;
  mapping (bytes32 => PendingClaim) public pendingClaims;

  function getNumOffers() external view returns (uint length) {
    return offerIds.length;
  }

  function getNumEscrows() external view returns (uint length) {
    return escrowIds.length;
  }

  function getEthRequiredForEscrow() public view returns (uint ethAmount) {
    return createEscrowGasLimit.mul(oracleGasPrice) + 1 ether / 1000;  // TODO calculate properly
  }

  function getEthRequiredForClaim() public view returns (uint ethAmount) {
    return claimEscrowGasLimit.mul(oracleGasPrice) + 1 ether / 10000;  // TODO calculate properly
  }

  function setOracleResponseGasPrice(uint priceInWei) external onlyOwner {
    oraclize_setCustomGasPrice(priceInWei);
    oracleGasPrice = priceInWei;
  }

  function withdrawEth() external onlyOwner {
    msg.sender.transfer(address(this).balance);
  }

  function withdrawDai() external onlyOwner {
    //TODO this allows stealing from existing escrows, but also allows fixing if something goes wrong. Only keep latter.
    transferDai(address(this), msg.sender, getDaiBalance(address(this)));
  }

  function createOffer(bool _long, string _currency, uint _dai, uint margin, uint positiveDeltaCents,
                       uint negativeDeltaCents) external {
    require(_dai >= minimumDai);
    transferDai(msg.sender, address(this), _dai);
    offers[currentId] = Offer(msg.sender, _long, _currency, _dai, offerIds.push(currentId) - 1, margin,
                              positiveDeltaCents, negativeDeltaCents);
    currentId++;
    emit NewOffer();
  }

  function _deleteOffer(uint64 _offerId) internal {
    uint listIndex = offers[_offerId].listIndex;
    offerIds[listIndex] = offerIds[offerIds.length - 1];
    offers[offerIds[listIndex]].listIndex = listIndex;
    delete offers[_offerId];
    offerIds.length --;
    emit OfferDeleted();
  }

  function deleteOffer(uint64 _offerId) external {
    require(msg.sender == offers[_offerId].maker);
    transferDai(address(this), msg.sender, offers[_offerId].dai);
    _deleteOffer(_offerId);
  }

  function _deleteEscrow(uint64 _escrowId) internal {
    uint listIndex = escrows[_escrowId].listIndex;
    escrowIds[listIndex] = escrowIds[escrowIds.length - 1];
    escrows[escrowIds[listIndex]].listIndex = listIndex;
    escrowIds.length --;
    delete escrows[_escrowId];
  }

  function createEscrow(uint64 _offerId) external payable {
    require(msg.value >= getEthRequiredForEscrow());  // TODO calculate properly
    if (oraclize_getPrice("URL") > address(this).balance) {
        emit LogNewOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
    } else {
        emit LogNewOraclizeQuery("Oraclize query was sent, standing by for the answer..");
        bytes32 queryId = oraclize_query("URL", strConcat("json(https://www.bitstamp.net/api/v2/ticker/",
                                         offers[_offerId].currency, ").last"), createEscrowGasLimit);
        pendingTakes[queryId] = PendingTake(msg.sender, _offerId);
    }
  }

  function claimEscrow(uint64 _escrowId) external payable {
    require(msg.value >= getEthRequiredForClaim());  // TODO calculate properly
    if (oraclize_getPrice("URL") > address(this).balance) {
        emit LogNewOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
    } else {
        emit LogNewOraclizeQuery("Oraclize query was sent, standing by for the answer..");
        bytes32 queryId = oraclize_query("URL", strConcat("json(https://www.bitstamp.net/api/v2/ticker/",
                                         escrows[_escrowId].currency, ").last"), claimEscrowGasLimit);
        pendingClaims[queryId] = PendingClaim(msg.sender, _escrowId);
    }
  }

  function __callback(bytes32 myid, string result) public {
    require(msg.sender == oraclize_cbAddress());
    if(pendingTakes[myid].offerId != 0) {
      completeEscrowCreation(pendingTakes[myid], result);
    }
    else {
      if(pendingClaims[myid].escrowId != 0) {
        completeEscrowClaim(pendingClaims[myid], result);
      }
    }
  }

  function completeEscrowCreation(PendingTake _take, string priceResult) internal {
    Offer memory offer = offers[_take.offerId];
    require(offer.dai > 0);  // check it is a real initialised offer
    transferDai(_take.taker, address(this), offer.dai);
    uint startPriceCents = parseInt(priceResult, 2);
    escrows[currentId] = Escrow(offer.maker, _take.taker, offer.makerIsLong, offer.currency, offer.dai.mul(99).div(50),
                                escrowIds.push(currentId) - 1, startPriceCents, offer.margin,
                                startPriceCents + offer.positiveDeltaCents, startPriceCents - offer.negativeDeltaCents);
    currentId++;
    _deleteOffer(_take.offerId);
    emit NewEscrow();
  }

  function completeEscrowClaim(PendingClaim _pendingClaim, string priceResult) internal {
    Escrow memory escrow = escrows[_pendingClaim.escrowId];
    require(_pendingClaim.claimer == escrow.maker || _pendingClaim.claimer == escrow.taker);
    uint payoutForMaker = 0;
    uint payoutForTaker = 0;
    (payoutForMaker, payoutForTaker) = calculateReturns(escrow.margin, escrow.ceilingCents, escrow.floorCents,
                                                        escrow.dai, escrow.startPriceCents, escrow.makerIsLong,
                                                        priceResult);
    transferDai(address(this), escrow.maker, payoutForMaker);
    transferDai(address(this), escrow.taker, payoutForTaker);
    _deleteEscrow(_pendingClaim.escrowId);
    emit TradeCompleted();
  }

  function calculateReturns(uint margin, uint ceilingCents, uint floorCents, uint daiInEscrow,
                            uint startPriceCents, bool makerIsLong, string priceResult)
                            public pure returns (uint payoutForMaker, uint payoutForTaker) {
    uint payoutForLong = 0;
    uint payoutForShort = 0;
    uint finalPriceCents = parseInt(priceResult, 2);
    if (ceilingCents == floorCents) {
      int marginDelta = int(margin) * int(finalPriceCents - startPriceCents);
      int marginDeltaPlusStart = marginDelta + int(startPriceCents);
      if (marginDelta > int(startPriceCents)) {
        payoutForLong = daiInEscrow;
      }
      else if (marginDeltaPlusStart < 0) {
        payoutForLong = 0;
      }
      else {
        payoutForLong = (daiInEscrow * (uint(marginDeltaPlusStart))) / (2 * startPriceCents);
      }
      payoutForShort = daiInEscrow - payoutForLong;
    }
    else {
      require(finalPriceCents >= ceilingCents || finalPriceCents <= floorCents);
      if (finalPriceCents >= ceilingCents) {
        payoutForLong = daiInEscrow;
      }
      else {
        payoutForShort = daiInEscrow;
      }
    }

    if(makerIsLong) {
      return (payoutForLong, payoutForShort);
    }
    else {
      return (payoutForShort, payoutForLong);
    }
  }

  function() public payable { }
}
