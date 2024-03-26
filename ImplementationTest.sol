//SPDX-License-Identifier: MIT
pragma solidity >0.8.10;

import {Implementation} from "./Implementation.sol";

/// @title ImplementationTest
/// @notice This contract is used to test Implementation update

contract ImplementationTest is Implementation {
    function doesNothing() external pure returns (bool) {
        return true;
    }
}