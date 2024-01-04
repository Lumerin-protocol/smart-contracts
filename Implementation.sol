// SPDX-License-Identifier: MIT
pragma solidity >0.8.0;

import {Escrow} from "./Escrow.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {FeeRecipient} from "./Shared.sol";
import {CloneFactory} from "./CloneFactory.sol";

//MyToken is place holder for actual lumerin token, purely for testing purposes
contract Implementation is Initializable, Escrow {
    ContractState public contractState;
    Terms public terms;

    uint256 public startingBlockTimestamp; //the timestamp of the block when the contract was purchased
    address public buyer; //address of the current purchaser of the contract
    address public seller; //address of the seller of the contract
    address public cloneFactory;
    address validator;
    string public encryptedPoolData; //encrypted data for pool target info
    string public pubKey; //encrypted data for pool target info
    bool public isDeleted; //used to track if the contract is deleted, separate variable to account for the possibility of a contract being deleted when it is still running
    HistoryEntry[] public history;
    Terms public futureTerms;
    
    enum ContractState {
        Available,
        Running
    }


    struct Terms {
        uint256 _price; // cost to purchase contract
        uint256 _limit; // variable used to aid in the lumerin nodes decision making // Not used anywhere
        uint256 _speed; // th/s of contract
        uint256 _length; // how long the contract will last in seconds
        uint32 _version;
        int8 _profitTarget;
    }

    struct HistoryEntry {
        bool _goodCloseout; // consider dropping and use instead _purchaseTime + _length >= _endTime
        uint256 _purchaseTime;
        uint256 _endTime;
        uint256 _price;
        uint256 _speed;
        uint256 _length;
        address _buyer;
    }

    event contractPurchased(address indexed _buyer); //make indexed
    event contractClosed(address indexed _buyer);
    event purchaseInfoUpdated(address indexed _address);
    event cipherTextUpdated(string newCipherText);

    function initialize(
        uint256 _price,
        uint256 _limit,
        uint256 _speed,
        uint256 _length,
        int8 _profitTarget,
        address _seller,
        address _lmrAddress,
        address _cloneFactory, //used to restrict purchasing power to only the clonefactory
        address _validator,
        string calldata _pubKey
    ) public initializer {
        terms = Terms(_price, _limit, _speed, _length, 0, _profitTarget);
        seller = _seller;
        cloneFactory = _cloneFactory;
        contractState = ContractState.Available;
        pubKey = _pubKey;
        validator = _validator;
        Escrow.initialize(_lmrAddress);
    }

    function getPublicVariables()
        public
        view
        returns (
            ContractState _state,
            uint256 _price,
            uint256 _limit,
            uint256 _speed,
            uint256 _length,
            uint256 _startingBlockTimestamp,
            address _buyer,
            address _seller,
            string memory _encryptedPoolData,
            bool _isDeleted,
            uint256 _balance,
            bool _hasFutureTerms,
            uint32 _version
        )
    {
        bool hasFutureTerms = futureTerms._length != 0;
        return (
            contractState,
            terms._price,
            terms._limit,
            terms._speed,
            terms._length,
            startingBlockTimestamp,
            buyer,
            seller,
            encryptedPoolData,
            isDeleted,
            lumerin.balanceOf(address(this)),
            hasFutureTerms,
            terms._version
        );
    }

    function getPublicVariablesV2()
        public
        view
        returns (
            ContractState _state,
            Terms memory _terms,
            uint256 _startingBlockTimestamp,
            address _buyer,
            address _seller,
            string memory _encryptedPoolData,
            bool _isDeleted,
            uint256 _balance,
            bool _hasFutureTerms
        )
    {
        bool hasFutureTerms = futureTerms._length != 0;
        return (
            contractState,
            terms,
            startingBlockTimestamp,
            buyer,
            seller,
            encryptedPoolData,
            isDeleted,
            lumerin.balanceOf(address(this)),
            hasFutureTerms
        );
    }

    function getHistory(uint256 _offset, uint256 _limit) public view returns (HistoryEntry[] memory) {
        if (_offset > history.length) {
            _offset = history.length;
        }
        if (_offset + _limit > history.length) {
            _limit = history.length - _offset;
        }
         
        HistoryEntry[] memory values = new HistoryEntry[](_limit);
        for (uint256 i = 0; i < _limit; i++) {
            // return values in reverse historical for displaying purposes
            values[i] = history[history.length - 1 - _offset - i];
        }

        return values;
    }

    function getStats() public view returns (uint256 _successCount, uint256 _failCount){
        uint256 successCount = 0;
        uint256 failCount = 0;
        for (uint256 i = 0; i < history.length; i++) {
            if (history[i]._goodCloseout) {
                successCount++;
            } else {
                failCount++;
            }
        }
        return (successCount, failCount);
    }

    //function that the clone factory calls to purchase the contract
    function setPurchaseContract(
        string calldata _encryptedPoolData,
        address _buyer
    ) public {
        require(
            msg.sender == cloneFactory,
            "this address is not approved to call the purchase function"
        );
        require(
            contractState == ContractState.Available,
            "contract is not in an available state"
        );
        encryptedPoolData = _encryptedPoolData;
        buyer = _buyer;
        startingBlockTimestamp = block.timestamp;
        contractState = ContractState.Running;
        createEscrow(seller, buyer, terms._price);
        emit contractPurchased(msg.sender);
    }

    //allows the buyers to update their mining pool information
    //during the lifecycle of the contract
    function setUpdateMiningInformation(string calldata _newEncryptedPoolData)
        external
    {
        require(
            msg.sender == buyer,
            "this account is not authorized to update the ciphertext information"
        );
        require(
            contractState == ContractState.Running,
            "the contract is not in the running state"
        );
        encryptedPoolData = _newEncryptedPoolData;
        emit cipherTextUpdated(_newEncryptedPoolData);
    }

    //function which can edit the cost, length, and hashrate of a given contract
    function setUpdatePurchaseInformation(
        uint256 _price,
        uint256 _limit,
        uint256 _speed,
        uint256 _length,
        int8 _profitTarget
    ) external {
        require(
            msg.sender == cloneFactory,
            "this address is not approved to call this function"
        );
        if (contractState == ContractState.Running) {
            futureTerms = Terms(_price, _limit, _speed, _length, terms._version + 1, _profitTarget);
        } else {
            terms = Terms(_price, _limit, _speed, _length, terms._version + 1, _profitTarget);
            emit purchaseInfoUpdated(address(this));
        }
    }

    function resetContractVariablesAndApplyFutureTerms() internal {
        buyer = address(0);
        encryptedPoolData = "";
        contractState = ContractState.Available;

        if(futureTerms._length != 0) {
            terms = Terms(futureTerms._price, futureTerms._limit, futureTerms._speed, futureTerms._length, futureTerms._version, futureTerms._profitTarget);
            futureTerms = Terms(0, 0, 0, 0, 0, 0);
            emit purchaseInfoUpdated(address(this));
        }
    }

    function getBuyerPayout() internal view returns (uint256) {
        uint256 elapsedContractTime = (block.timestamp - startingBlockTimestamp);
        if (elapsedContractTime <= terms._length) {
            // order of operations is important as we are dealing with uint256!
           return terms._price - terms._price * elapsedContractTime / terms._length;
        }
        return 0;
    }

    function setContractCloseOut(uint256 closeOutType) public payable {
        if (closeOutType == 0) {
            // this closeoutType is only for the buyer to close early
            // and withdraw their funds
            require(
                msg.sender == buyer || msg.sender == validator,
                "this account is not authorized to trigger an early closeout"
            );
            require(
                contractState == ContractState.Running,
                "the contract is not in the running state"
            );

            uint256 buyerPayout = getBuyerPayout();
            bool comp = block.timestamp - startingBlockTimestamp >= terms._length;
            history.push(HistoryEntry(comp, startingBlockTimestamp, block.timestamp, terms._price, terms._speed, terms._length, buyer));
            resetContractVariablesAndApplyFutureTerms();
            emit contractClosed(buyer);
            
            bool sent = withdrawFundsBuyer(buyerPayout);
            require(sent, "Failed to withdraw funds");
        } else if (closeOutType == 1) {
            // this closeoutType is only for the seller to withdraw their funds
            // at any time during the smart contracts lifecycle

            require(
                msg.sender == seller,
                "this account is not a seller of this contract"
            );

            uint256 amountToKeepInEscrow = 0;

            if (contractState == ContractState.Running) {
                // if contract is running we need to keep some funds 
                // in the escrow for refund if seller cancels contract 
                amountToKeepInEscrow = getBuyerPayout();
            }

            bool sent = withdrawAllFundsSeller(amountToKeepInEscrow);
            require(sent, "Failed to withdraw funds");
            
            sent = CloneFactory(cloneFactory).payMarketplaceFee{value:msg.value}();
            require(sent, "Failed to pay marketplace withdrawal fee");
        } else if (closeOutType == 2) {
            // this closeoutType is only for the seller to closeout after contract ended
            // without claiming funds, keeping them in the escrow
            require(
                block.timestamp - startingBlockTimestamp >= terms._length,
                "the contract has yet to be carried to term"
            );
            require(
                contractState == ContractState.Running,
                "the contract is not in the running state"
            );

            history.push(HistoryEntry(true, startingBlockTimestamp, block.timestamp, terms._price, terms._speed, terms._length, buyer));

            resetContractVariablesAndApplyFutureTerms();
            emit contractClosed(buyer);
        }
        else if (closeOutType == 3){
            // this closeoutType is only for the seller to closeout after contract ended
            // and claim all funds collected in the escrow
            require(
                msg.sender == seller,
                "only the seller can closeout AND withdraw after contract term"
            );
            require(
                block.timestamp - startingBlockTimestamp >= terms._length,
                "the contract has yet to be carried to term"
            );
            require(
                contractState == ContractState.Running,
                "the contract is not in the running state"
            );

            history.push(HistoryEntry(true, startingBlockTimestamp, block.timestamp, terms._price, terms._speed, terms._length, buyer));

            resetContractVariablesAndApplyFutureTerms();
            emit contractClosed(buyer);

            bool sent = CloneFactory(cloneFactory).payMarketplaceFee{value:msg.value}();
            require(sent, "Failed to pay marketplace withdrawal fee");
            
            sent = withdrawAllFundsSeller(0);
            require(sent, "Failed to withdraw funds");
        } else {
            revert("you must make a selection from 0 to 3");
        }
    }

    function setContractDeleted(bool _isDeleted) public {
        require(
            msg.sender == cloneFactory,
            "this address is not approved to call this function"
        );

        require(
            isDeleted != _isDeleted,
            "contract delete state is already set to this value"
        );
        
        isDeleted = _isDeleted;
    }
}
