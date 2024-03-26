// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (finance/VestingWallet.sol)
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "hardhat/console.sol";



//vesting wallet logic to support calling multiple contracts
contract VestingWalletMulti is Context {
    event EtherReleased(uint256 amount);
    event ERC20Released(address indexed token, uint256 amount);

    uint256 private _released;
    address Lumerin;
    //total number of tokens to be vested
    mapping(address => uint256) _erc20VestingAmount;
    //keeps track of how many tokens have been vested
    mapping(address => uint256) _erc20Released; 
    //determines which vesting schedule to follow
    mapping(address => uint8) _whichVestingSchedule;
    //used to prevent reentrance
    mapping(address => bool) _isVesting;
    uint64 private _start;
    uint64 private _duration;
    bool private initialized = false;

    /**
     * @dev Set the beneficiary, start timestamp and vesting duration of the vesting wallet.
     */
     constructor(address _lumerin) {
         _lumerin = Lumerin;
     }

    /**
     * @dev Getter for the start timestamp.
     */
    function start() public view virtual returns (uint256) {
        return _start;
    }

    function setAddToVestingAmount(address _claiment, uint _value) public {
        _erc20VestingAmount[_claiment] = _value;
    }



    /**
     * @dev Getter for the vesting duration.
     */
    function duration() public view virtual returns (uint256) {
        return _duration;
    }

    /**
     * @dev Amount of token already released
     */
    function released() public view returns (uint256) {
        return _erc20Released[msg.sender];
    }

    /**
     * @dev Release the tokens that have already vested.
     *
     * Emits a {TokensReleased} event.
     */
     //double check for leaks as this may leave the msg.sender vulnerabl
    function release() public virtual {
        uint256 releasable = vestedAmount(msg.sender, uint64(block.timestamp)) - released();
        _erc20Released[msg.sender] += releasable;
        emit ERC20Released(Lumerin, releasable);
        SafeERC20.safeTransfer(IERC20(Lumerin), msg.sender, releasable);
    }

     //returns the total amount of lumerin tokens that could be vested assuming none have been
     //vested. 
    function vestedAmount(address claiment, uint64 timestamp) public view virtual returns (uint256) {
        return _vestingSchedule(_erc20VestingAmount[claiment], timestamp);
    }

    /**
     * @dev Virtual implementation of the vesting formula. This returns the amout vested, as a function of time, for
     * an asset given its total historical allocation.
     */
     //overridden in the main contract
    function _vestingSchedule(uint256 totalAllocation, uint64 timestamp) internal view virtual returns (uint256) {
        if (timestamp < start()) {
            return 0;
        } else if (timestamp > start() + duration()) {
            return totalAllocation;
        } else {
            return (totalAllocation * (timestamp - start())) / duration();
        }
    }
}
