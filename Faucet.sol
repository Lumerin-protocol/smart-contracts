// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "./LumerinToken.sol";

contract Faucet {
      address owner;
      uint public cooldownPeriod;
      uint public cooldownStartingTime;
      uint public currentLMRTokenDistribution;
      uint public lmrTokenDistributionMax;
      uint public lmrPayout;
      uint public ethPayout;

      mapping(address => uint) lastClaimed;
      mapping(string => uint) lastClaimedIP;
      Lumerin lumerin;

      constructor(address _lmr, uint _dailyMaxLmr, uint _lmrPayout, uint _ethPayout) payable {
          owner = payable(msg.sender);
          cooldownStartingTime = block.timestamp;
          cooldownPeriod = 24*60*60;
          
          lumerin = Lumerin(_lmr);
          currentLMRTokenDistribution = 0;
          lmrTokenDistributionMax = _dailyMaxLmr;
          lmrPayout = _lmrPayout;
          ethPayout = _ethPayout;
      }

      modifier onlyOwner {
        require(msg.sender == owner, "you are not authorized to call this function");
        _;
      }

      modifier dailyMaxLmrModifier {
        require(currentLMRTokenDistribution < lmrTokenDistributionMax, "the daily limit of test lumerin has been distributed");
        _;
      }

      receive() external payable {}

      //allows the owner of this contract to send tokens to the claiment
      function supervisedClaim(address _claiment, string calldata _ipAddress) public onlyOwner dailyMaxLmrModifier {
          require(canClaimTokens(_claiment, _ipAddress), "you need to wait before claiming");

          lastClaimed[_claiment] = block.timestamp;
          lastClaimedIP[_ipAddress] = block.timestamp;
          currentLMRTokenDistribution = currentLMRTokenDistribution + lmrPayout;
          refreshDailyMaxLmr();

          lumerin.transfer(_claiment, lmrPayout);
          payable(_claiment).transfer(ethPayout); //sends amount in wei to recipient
      }

      function refreshDailyMaxLmr() internal {
        if (cooldownStartingTime + cooldownPeriod < block.timestamp) {
          cooldownStartingTime = block.timestamp;
          currentLMRTokenDistribution = 0;
        }
      }

      function setUpdateEthPayout(uint _ethPayout) public onlyOwner {
          ethPayout = _ethPayout;
      }

      function setUpdateLmrPayout(uint _lmrPayout) public onlyOwner {
          lmrPayout = _lmrPayout;
      }

      function setUpdatedailyMaxLmr(uint _dailyMaxLmr) public onlyOwner {
          lmrTokenDistributionMax = _dailyMaxLmr;
      }

      function resetDistributedTodayLmr() public onlyOwner {
          cooldownStartingTime = block.timestamp;
          currentLMRTokenDistribution = 0;
      }

      function setUpdateLumerin(address _lmr) public onlyOwner {
        lumerin = Lumerin(_lmr);
      }

      function setUpdateOwner(address _newOwner) public onlyOwner {
        owner = _newOwner;
      }

      function setTransferLumerin(address _to, uint _amount) public onlyOwner {
        lumerin.transfer(_to, _amount);
      }

      function emptyGeth() public onlyOwner {
          payable(owner).transfer(address(this).balance); //sends amount in wei to recipient
      }

      function canClaimTokens(address _address, string calldata _ipAddress) public view returns (bool) {
          return lastClaimed[_address] + cooldownPeriod <= block.timestamp
            && lastClaimedIP[_ipAddress] + cooldownPeriod <= block.timestamp;
      }
}
