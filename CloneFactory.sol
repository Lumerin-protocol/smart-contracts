//SPDX-License-Identifier: MIT
pragma solidity >0.8.10;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {Implementation} from "./Implementation.sol";
import {Lumerin} from "./LumerinToken.sol";
import {FeeRecipient} from "./Shared.sol";

/// @title CloneFactory
/// @author Josh Kean (Lumerin)
/// @notice Variables passed into contract initializer are subject to change based on the design of the hashrate contract

//CloneFactory now responsible for minting, purchasing, and tracking contracts
contract CloneFactory is Initializable {
    Lumerin lumerin;
    address public baseImplementation;
    address public owner;
    bool public noMoreWhitelist;
    address[] public rentalContracts; //dynamically allocated list of rental contracts
    mapping(address => bool) rentalContractsMap; //mapping of rental contracts to verify cheaply if implementation was created by this clonefactory
    FeeRecipient feeRecipient;


    mapping(address => bool) public whitelist; //whitelisting of seller addresses //temp public for testing
    mapping(address => bool) public isContractDead; // keeps track of contracts that are no longer valid

    event contractCreated(address indexed _address, string _pubkey); //emitted whenever a contract is created
    event clonefactoryContractPurchased(address indexed _address); //emitted whenever a contract is purchased
    event contractDeleteUpdated(address _address, bool _isDeleted); //emitted whenever a contract is deleted/restored
    event purchaseInfoUpdated(address indexed _address);

    modifier onlyOwner() {
        require(msg.sender == owner, "you are not authorized");
        _;
    }

    modifier sufficientFee() {
        require(msg.value >= feeRecipient.fee, "Insufficient ETH provided for marketplace fee");
        _;
    }

    modifier onlyInWhitelist() {
        require(
            whitelist[msg.sender] || noMoreWhitelist,
            "you are not an approved seller on this marketplace"
        );
        _;
    }

    function initialize(address _baseImplementation, address _lumerin, address _feeRecipient) public initializer {
        lumerin = Lumerin(_lumerin);
        baseImplementation = _baseImplementation;
        owner = msg.sender;
        feeRecipient.fee = 0.0002 ether;
        feeRecipient.recipient = _feeRecipient;
    }

    function payMarketplaceFee()
        public payable sufficientFee returns (bool) {
        (bool sent,) = payable(feeRecipient.recipient).call{value: feeRecipient.fee}("");
        require(sent, "Failed to pay marketplace listing fee");
        return sent;
    }

    function marketplaceFee()
        external view  returns (uint256) {
        return feeRecipient.fee;
    }

    //function to create a new Implementation contract
    function setCreateNewRentalContract(
        uint256 _price,
        uint256 _limit,
        uint256 _speed,
        uint256 _length,
        address _validator,
        string calldata _pubKey
    ) external payable onlyInWhitelist sufficientFee returns (address) {

        /* ETH seller marketplace listing fee */
        bool sent = payMarketplaceFee();
        require(sent, "Failed to pay marketplace listing fee");

        bytes memory data = abi.encodeWithSelector(
            Implementation(address(0)).initialize.selector,
            _price,
            _limit,
            _speed,
            _length,
            msg.sender,
            address(lumerin),
            address(this),
            _validator,
            _pubKey
        );

        BeaconProxy beaconProxy = new BeaconProxy(baseImplementation, data);
        address newContractAddr = address(beaconProxy);
        rentalContracts.push(newContractAddr); //add clone to list of contracts
        rentalContractsMap[newContractAddr] = true;
        emit contractCreated(newContractAddr, _pubKey); //broadcasts a new contract and the pubkey to use for encryption
        return newContractAddr;
    }

    //function to purchase a hashrate contract
    //requires the clonefactory to be able to spend tokens on behalf of the purchaser
    function setPurchaseRentalContract(
        address _contractAddress,
        string calldata _cipherText,
        uint32 termsVersion
    ) external payable sufficientFee {
        // TODO: add a test case so any third-party implementations will be discarded
        require(rentalContractsMap[_contractAddress], "unknown contract address");
        Implementation targetContract = Implementation(_contractAddress);
        require(
            !targetContract.isDeleted(), "cannot purchase deleted contract");
        require(
            targetContract.seller() != msg.sender,
            "cannot purchase your own contract"
        );

        (uint256 _price,,,, uint32 _version) = targetContract.terms();

        require(
            _version == termsVersion,
            "cannot purchase, contract terms were updated"
        );

        /* ETH buyer marketplace purchase fee */
        bool sent = payMarketplaceFee();
        require(sent, "Failed to pay marketplace purchase fee");

        uint256 requiredAllowance = _price;
        uint256 actualAllowance = lumerin.allowance(msg.sender, address(this));
        require(
            actualAllowance >= requiredAllowance,
            "not authorized to spend required funds"
        );

        bool tokensTransfered = lumerin.transferFrom(
            msg.sender,
            _contractAddress,
            _price
        );
        require(tokensTransfered, "lumerin transfer failed");

        targetContract.setPurchaseContract(
            _cipherText,
            msg.sender
        );

        emit clonefactoryContractPurchased(_contractAddress);
    }

    function getContractList() external view returns (address[] memory) {
        address[] memory _rentalContracts = rentalContracts;
        return _rentalContracts;
    }

    //adds an address to the whitelist
    function setAddToWhitelist(address _address) external onlyOwner {
        whitelist[_address] = true;
    }

    //remove an address from the whitelist
    function setRemoveFromWhitelist(address _address) external onlyOwner {
        whitelist[_address] = false;
    }

    function checkWhitelist(address _address) external view returns (bool) {
        if (noMoreWhitelist) {
            return true;
        }
        return whitelist[_address];
    }

    function setDisableWhitelist() external onlyOwner {
        noMoreWhitelist = true;
    }

    function setMarketplaceFeeRecipient(uint256 fee, address recipient) external onlyOwner {
        feeRecipient.fee = fee;
        feeRecipient.recipient = recipient;
    }

    function setContractDeleted(address _contractAddress, bool _isDeleted) public {
        require(rentalContractsMap[_contractAddress], "unknown contract address");
        Implementation _contract = Implementation(_contractAddress);
        require(msg.sender == _contract.seller() || msg.sender == owner, "you are not authorized");
        Implementation(_contractAddress).setContractDeleted(_isDeleted);
        emit contractDeleteUpdated(_contractAddress, _isDeleted);
    }

    function setUpdateContractInformation(
        address _contractAddress,      
        uint256 _price,
        uint256 _limit,
        uint256 _speed,
        uint256 _length
    ) external payable sufficientFee {
        require(rentalContractsMap[_contractAddress], "unknown contract address");
        Implementation _contract = Implementation(_contractAddress);
        require(msg.sender == _contract.seller(), "you are not authorized");

        /* ETH seller marketplace listing fee */
        bool sent = payMarketplaceFee();
        require(sent, "Failed to pay marketplace listing fee");

        Implementation(_contractAddress).setUpdatePurchaseInformation(_price, _limit, _speed, _length);
        emit purchaseInfoUpdated(address(this));
    }
}
