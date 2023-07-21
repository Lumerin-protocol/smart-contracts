//SPDX-License-Identifier: MIT

pragma solidity >0.8.0;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Implementation.sol";
import "./LumerinToken.sol";

/// @title CloneFactory
/// @author Josh Kean (Lumerin)
/// @notice Variables passed into contract initializer are subject to change based on the design of the hashrate contract

//CloneFactory now responsible for minting, purchasing, and tracking contracts
contract CloneFactory {
    address baseImplementation;
    address validator;
    address lmnDeploy;
    address webfacingAddress;
    address owner;
    address marketPlaceFeeRecipient; //address where the marketplace fee's are sent
    address[] public rentalContracts; //dynamically allocated list of rental contracts
    uint256 public buyerFeeRate; //fee to be paid to the marketplace
    uint256 public sellerFeeRate; //fee to be paid to the marketplace
    bool public noMoreWhitelist;

    mapping(address => bool) rentalContractsMap; //mapping of rental contracts to verify cheaply if implementation was created by this clonefactory
    mapping(address => bool) whitelist; //whitelisting of seller addresses
    Lumerin lumerin;

    constructor(address _lmn, address _validator) {
        Implementation _imp = new Implementation();
        baseImplementation = address(_imp);
        lmnDeploy = _lmn; //deployed address of lumerin token
        validator = _validator;
        lumerin = Lumerin(_lmn);
        owner = msg.sender;
        marketPlaceFeeRecipient = msg.sender;

        buyerFeeRate = 100;
        sellerFeeRate = 100;
    }

    event contractCreated(address indexed _address, string _pubkey); //emitted whenever a contract is created
    event clonefactoryContractPurchased(address indexed _address); //emitted whenever a contract is purchased
    event contractDeleteUpdated(address _address, bool _isDeleted); //emitted whenever a contract is deleted/restored
    event purchaseInfoUpdated(address indexed _address);

    modifier onlyOwner() {
        require(msg.sender == owner, "you are not authorized");
        _;
    }

    modifier onlyInWhitelist() {
        require(
            whitelist[msg.sender] || noMoreWhitelist,
            "you are not an approved seller on this marketplace"
        );
        _;
    }

    //function to create a new Implementation contract
    function setCreateNewRentalContract(
        uint256 _price,
        uint256 _limit,
        uint256 _speed,
        uint256 _length,
        address _validator,
        string calldata _pubKey
    ) external onlyInWhitelist returns (address) {
        address _newContract = Clones.clone(baseImplementation);
        Implementation(_newContract).initialize(
            _price,
            _limit,
            _speed,
            _length,
            msg.sender,
            lmnDeploy,
            address(this),
            _validator,
            _pubKey
        );
        rentalContracts.push(_newContract); //add clone to list of contracts
        rentalContractsMap[_newContract] = true; //add clone to mapping of contracts
        emit contractCreated(_newContract, _pubKey); //broadcasts a new contract and the pubkey to use for encryption
        return _newContract;
    }

    //function to purchase a hashrate contract
    //requires the clonefactory to be able to spend tokens on behalf of the purchaser
    function setPurchaseRentalContract(
        address _contractAddress,
        string calldata _cipherText
    ) external {
        // TODO: add a test case so any third-party implementations will be discarded
        require(rentalContractsMap[_contractAddress], "unknown contract address");
        Implementation targetContract = Implementation(_contractAddress);
        require(
            !targetContract.isDeleted(), "cannot purchase deleted contract");
        require(
            targetContract.seller() != msg.sender,
            "cannot purchase your own contract"
        );

        (uint256 _price,,,) = targetContract.terms();
        uint256 _marketplaceFee = _price / buyerFeeRate;

        uint256 requiredAllowance = _price + _marketplaceFee;
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

        bool feeTransfer = lumerin.transferFrom(
            msg.sender,
            marketPlaceFeeRecipient,
            _marketplaceFee
        );

        require(feeTransfer, "marketplace fee not paid");
        targetContract.setPurchaseContract(
            _cipherText,
            msg.sender,
            marketPlaceFeeRecipient,
            sellerFeeRate
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

    function setChangeSellerFeeRate(uint256 _newFee) external onlyOwner {
        sellerFeeRate = _newFee;
    }

    function setChangeBuyerFeeRate(uint256 _newFee) external onlyOwner {
        buyerFeeRate = _newFee;
    }

    function setChangeMarketplaceRecipient(
        address _newRecipient
    ) external onlyOwner {
        marketPlaceFeeRecipient = _newRecipient;
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
    ) public {
        require(rentalContractsMap[_contractAddress], "unknown contract address");
        Implementation _contract = Implementation(_contractAddress);
        require(msg.sender == _contract.seller(), "you are not authorized");
        Implementation(_contractAddress).setUpdatePurchaseInformation(_price, _limit, _speed, _length);
    }

    // for test purposes, this allows us to configure our test environment so the ABI's can be matched with the Implementation contract source.
    function setBaseImplementation(
        address _newImplementation
    ) external onlyOwner {
        baseImplementation = _newImplementation;
    }
}
