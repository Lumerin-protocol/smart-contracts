// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Marketplace Escrow
/// @author Lance Seidman (Lumerin)
/// @notice This first version will be used to hold lumerin temporarily for the Marketplace Hash Rental.

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./LumerinToken.sol";

contract Escrow is Initializable, ReentrancyGuardUpgradeable {
    address public escrow_purchaser; // Entity making a payment...
    address public escrow_seller; // Entity to receive funds...
    uint256 public contractTotal; // How much should be escrowed...
    // uint256 public receivedTotal; // Optional; Keep a balance for how much has been received...
    uint256 marketplaceFeeRate; // amount of fee to be sent to the fee recipient (marketPlaceFeeRecipient)
    address marketPlaceFeeRecipient; //address where the marketplace fee's are sent

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
        uint256 _lumerinTotal,
        address _marketPlaceFeeRecipient,
        uint256 _marketplaceFeeRate
    ) internal {
        escrow_seller = _escrow_seller;
        escrow_purchaser = _escrow_purchaser;
        contractTotal = _lumerinTotal;
        marketPlaceFeeRecipient = _marketPlaceFeeRecipient;
        marketplaceFeeRate = _marketplaceFeeRate;
    }

    // @notice Validator can request the funds to be released once determined it's safe to do.
    // @dev Function makes sure the contract was fully funded
    // by checking the State and if so, release the funds to the seller.
    // sends lumerin tokens to the appropriate entities.
    // _buyer will obtain a 0 value unless theres a penalty involved
    function withdrawFunds(
        uint256 _seller,
        uint256 _buyer
    ) internal nonReentrant {
        if (_seller != 0) {
            uint256 fee = calculateFee(_seller);
            lumerin.transfer(marketPlaceFeeRecipient, fee);

            lumerin.transfer(escrow_seller, _seller - fee);
        }

        if (_buyer != 0) {
            lumerin.transfer(escrow_purchaser, _buyer);
        }

    }

    //internal function which transfers current hodled tokens into sellers account
    function getDepositContractHodlingsToSeller(uint256 remaining) internal {
        uint256 balance = lumerin.balanceOf(address(this)) - remaining;
        uint256 fee = calculateFee(balance);
        uint256 transferrableBalance = balance - fee;

        lumerin.transfer(marketPlaceFeeRecipient, fee);

        lumerin.transfer(escrow_seller, transferrableBalance);
    }

    function calculateFee(uint256 revenue) internal view returns (uint256) {
        return revenue / marketplaceFeeRate;
    }
}
