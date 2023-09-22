//SPDX-License-Identifier: MIT
pragma solidity >0.8.10;

import {CloneFactory} from "./CloneFactory.sol";

/// @title CloneFactoryTest
/// @notice This contract is used to test Clonefactory update

contract CloneFactoryTest is CloneFactory {
    function doesNothing() external pure returns (bool) {
        return true;
    }
}
