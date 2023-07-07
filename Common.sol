pragma solidity > 0.8.0;

contract Common {
    struct SellerHistory {
        bool goodCloseout;
        uint256 _purchaseTime;
        uint256 endingTime;
        uint256 _price;
        uint256 _speed;
        uint256 _length;
        address _buyer;
    }
}
