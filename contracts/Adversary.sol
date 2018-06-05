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
    uint PositiveDelta;  // nano units
    uint NegativeDelta;  // nano units
    uint lockSeconds;
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
    uint StartPrice;  // nano units
    uint margin;
    uint CeilingPrice;  // nano units
    uint FloorPrice;  // nano units
    uint unlockSecond;
  }

  uint constant public oneDai = 10 ** 18;
  uint constant public minimumDai = 10 * oneDai;
  uint constant public createEscrowGasLimit = 400000;  // TODO set once code is finalised
  uint constant public claimEscrowGasLimit = 400000;  // TODO calculate in testing
  bytes32 constant public rescueKey = "signtodestroyescrow";

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
    return createEscrowGasLimit.mul(oracleGasPrice) + 1 ether / 1000;  // TODO calculate properly when finalised
  }

  function getEthRequiredForClaim() public view returns (uint ethAmount) {
    return claimEscrowGasLimit.mul(oracleGasPrice) + 1 ether / 10000;  // TODO calculate properly when finalised
  }

  function setOracleResponseGasPrice(uint priceInWei) internal {
    oraclize_setCustomGasPrice(priceInWei);
    oracleGasPrice = priceInWei;
  }

  /*  @param _long, If true the offer maker is long and profits when the result increases and vice versa.
      @param _currency, String to specify the symbol used in bitfinex api, eg "ETHUSD".
      @param _dai, Quantity of dai the maker and taker will contribute to the escrow.
      @param _margin, Integer which multiplies rate rewards change with price, use zero for step function rewards.
      @param _positiveDelta If margin is zero then the required increase from start price before long can
                            claim entire escrow. Nano units.
      @param _negativeDelta If margin is zero then the required decrease from start price before short can
                            claim entire escrow. Nano units.
      @param _lockSeconds Time after escrow starts before either party can claim escrow.
  */
  function createOffer(bool _long, string _currency, uint _dai, uint _margin, uint _positiveDelta,
                       uint _negativeDelta, uint _lockSeconds) external {
    require(_dai >= minimumDai);
    transferDai(msg.sender, address(this), _dai);
    offers[currentId] = Offer(msg.sender, _long, _currency, _dai, offerIds.push(currentId) - 1, _margin,
                              _positiveDelta, _negativeDelta, _lockSeconds);
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
    setOracleResponseGasPrice(tx.gasprice);
    require(msg.value >= getEthRequiredForEscrow());
    if (oraclize_getPrice("URL") > address(this).balance) {
        emit LogNewOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
    } else {
        emit LogNewOraclizeQuery("Oraclize query was sent, standing by for the answer..");
        bytes32 queryId = oraclize_query("URL", strConcat("json(https://api.bitfinex.com/v2/ticker/t",
                                         offers[_offerId].currency, ").[6]"), createEscrowGasLimit);
        pendingTakes[queryId] = PendingTake(msg.sender, _offerId);
    }
  }

  function claimEscrow(uint64 _escrowId) external payable {
    setOracleResponseGasPrice(tx.gasprice);
    require(msg.value >= getEthRequiredForClaim());
    if (oraclize_getPrice("URL") > address(this).balance) {
        emit LogNewOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
    } else {
        emit LogNewOraclizeQuery("Oraclize query was sent, standing by for the answer..");
        bytes32 queryId = oraclize_query("URL", strConcat("json(https://api.bitfinex.com/v2/ticker/t",
                                         escrows[_escrowId].currency, ").[6]"), claimEscrowGasLimit);
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
    uint StartPrice = parseInt(priceResult, 9);
    escrows[currentId] = Escrow(offer.maker, _take.taker, offer.makerIsLong, offer.currency, offer.dai.mul(995).div(500),
                                escrowIds.push(currentId) - 1, StartPrice, offer.margin,
                                StartPrice + offer.PositiveDelta, StartPrice - offer.NegativeDelta,
                                offer.lockSeconds + now);
    currentId++;
    _deleteOffer(_take.offerId);
    emit NewEscrow();
  }

  function completeEscrowClaim(PendingClaim _pendingClaim, string priceResult) internal {
    Escrow memory escrow = escrows[_pendingClaim.escrowId];
    require(_pendingClaim.claimer == escrow.maker || _pendingClaim.claimer == escrow.taker);
    require(now > escrow.unlockSecond);
    uint payoutForMaker = 0;
    uint payoutForTaker = 0;
    (payoutForMaker, payoutForTaker) = calculateReturns(escrow.margin, escrow.CeilingPrice, escrow.FloorPrice,
                                                        escrow.dai, escrow.StartPrice, escrow.makerIsLong,
                                                        priceResult);
    transferDai(address(this), escrow.maker, payoutForMaker);
    transferDai(address(this), escrow.taker, payoutForTaker);
    _deleteEscrow(_pendingClaim.escrowId);
    emit TradeCompleted();
  }

  function calculateReturns(uint margin, uint CeilingPrice, uint FloorPrice, uint daiInEscrow,
                            uint StartPrice, bool makerIsLong, string priceResult)
                            public pure returns (uint payoutForMaker, uint payoutForTaker) {
    uint payoutForLong = 0;
    uint payoutForShort = 0;
    uint FinalPrice = parseInt(priceResult, 9);
    if (margin == 0) {
      require(FinalPrice >= CeilingPrice || FinalPrice <= FloorPrice);
      if (FinalPrice >= CeilingPrice) {
        payoutForLong = daiInEscrow;
      }
      else {
        payoutForShort = daiInEscrow;
      }
    }
    else {
      int marginDelta = int(margin) * int(FinalPrice - StartPrice);
      int marginDeltaPlusStart = marginDelta + int(StartPrice);
      if (marginDelta > int(StartPrice)) {
        payoutForLong = daiInEscrow;
      }
      else if (marginDeltaPlusStart < 0) {
        payoutForLong = 0;
      }
      else {
        payoutForLong = (daiInEscrow * (uint(marginDeltaPlusStart))) / (2 * StartPrice);
      }
      payoutForShort = daiInEscrow - payoutForLong;
    }

    if(makerIsLong) {
      return (payoutForLong, payoutForShort);
    }
    else {
      return (payoutForShort, payoutForLong);
    }
  }

  function() public payable { }

  function withdrawEth() external onlyOwner {
    msg.sender.transfer(address(this).balance);
  }

  function withdrawDai() external onlyOwner {
    uint daiInUse = 0;
    for(uint i = 0; i < offerIds.length; i++) {
      daiInUse += offers[offerIds[i]].dai;
    }
    for(i = 0; i < escrowIds.length; i++) {
      daiInUse += escrows[escrowIds[i]].dai;
    }
    transferDai(address(this), msg.sender, getDaiBalance(address(this)) - daiInUse);
  }

  /* If an escrow gets stuck and both the maker and taker sign the key the escrow can be rescued and distributed equally
  */
  function rescueStuckEscrow(uint _escrowId, string _signedByMaker, string _signedByTaker) external {
    // TODO
  }
}

/*
TODO: Add method to rescue dai if error occurs
      fix calculation of oraclize fee.
      optimise for gas,check how much smaller struct members can be and place adjacent. At least uint64 for prices
*/
