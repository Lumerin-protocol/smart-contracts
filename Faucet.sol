pragma solidity >=0.8.0;

import "./LumerinToken.sol";

contract Faucet {
    /*
       this is a token faucet
       it allows people to claim tokens in a controlled manner
       */
      address owner;
      uint public cooldownPeriod;
      uint public startOfDay;
      uint public dailyLimitCount;
      uint public txAmount;
      uint public gethAmount;
      mapping(address => uint) lastClaimed;
      mapping(string => uint) lastClaimedIP;
      Lumerin lumerin;

      constructor(address _lmr) payable {
          owner = payable(msg.sender);
          startOfDay = block.timestamp;
          dailyLimitCount = 0;
          cooldownPeriod = 24*60*60;
          lumerin = Lumerin(_lmr); //lumerin token address
          txAmount = 10*10**lumerin.decimals();
          gethAmount = 5e16;
      }

      modifier onlyOwner {
        require(msg.sender == owner, "you are not authorized to call this function");
        _;
      }

      modifier dailyLimit {
        require(dailyLimitCount < 800, "the daily limit of test lumerin has been distributed");
        _;
      }

      receive() external payable {}

      //allows the owner of this contract to send tokens to the claiment
      function supervisedClaim(address _claiment, string calldata _ipAddress) public onlyOwner dailyLimit {
          require(canClaimTokens(_claiment, _ipAddress), "you need to wait before claiming");

          lumerin.transfer(_claiment, txAmount);
          payable(_claiment).transfer(gethAmount); //sends amount in wei to recipient
          
          lastClaimed[_claiment] = block.timestamp;
          lastClaimedIP[_ipAddress] = block.timestamp;
          
          dailyLimitCount = dailyLimitCount + 10;
          refreshDailyLimit();
      }

      function refreshDailyLimit() internal {
        if (startOfDay + cooldownPeriod < block.timestamp) {
          startOfDay = block.timestamp;
          dailyLimitCount = 0;
        }
      }

      function setUpdateCooldownPeriod(uint _cooldownPeriod) public onlyOwner {
          cooldownPeriod = _cooldownPeriod;
      }

      function setUpdateGWEIAmount(uint _gwei) public onlyOwner {
          gethAmount = _gwei;
      }

      function setUpdateTxAmount(uint _txAmount) public onlyOwner {
          txAmount = _txAmount*10**lumerin.decimals();
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
