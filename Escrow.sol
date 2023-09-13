// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Marketplace Escrow
/// @author Lance Seidman (Lumerin)
/// @notice This first version will be used to hold lumerin temporarily for the Marketplace Hash Rental.

import {ReentrancyGuardUpgradeable, Initializable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {Lumerin} from "./LumerinToken.sol";

contract Escrow is Initializable, ReentrancyGuardUpgradeable {
    address public escrow_purchaser; // Entity making a payment...
    address public escrow_seller; // Entity to receive funds...
    uint256 public contractTotal; // How much should be escrowed...
    // uint256 public receivedTotal; // Optional; Keep a balance for how much has been received...
    Lumerin lumerin;

    //internal function which will be called by the hashrate contract
    function initialize(address _lmrAddress) internal onlyInitializing {
        lumerin = Lumerin(_lmrAddress);
        __ReentrancyGuard_init();
    }

    // @notice This will create a new escrow based on the seller, buyer, and total.
    // @dev Call this in order to make a new contract.
    function createEscrow(
        address _escrow_seller,
        address _escrow_purchaser,
        uint256 _lumerinTotal
    ) internal {
        escrow_seller = _escrow_seller;
        escrow_purchaser = _escrow_purchaser;
        contractTotal = _lumerinTotal;
    }

    // withdraws specified amount of funds to buyer
    function withdrawFundsBuyer(uint256 amount) internal nonReentrant returns (bool){
        return lumerin.transfer(escrow_purchaser, amount);
    }

    // withdraws all funds except for the remaining amount to seller
    function withdrawAllFundsSeller(uint256 remaining) internal nonReentrant returns (bool) {
        uint256 balance = lumerin.balanceOf(address(this)) - remaining;
        return lumerin.transfer(escrow_seller, balance);
    }
}
