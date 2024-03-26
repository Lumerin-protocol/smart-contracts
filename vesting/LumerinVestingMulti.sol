// SPDX-License-Identifier: MIT
/*
Author: Josh Kean - Titan Mining
Date: 04-29-2022

This is a vesting contract to release funds to the Lumerin Token holders
It assumes monthly cliffs and multiple users from multiple tranches
*/

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./VestingWalletMulti.sol";


contract LumerinVestingMulti is VestingWalletMulti{
	//will have 4 dates of 5/28, 6/28, 7/28, and 8/28
	uint[] vestingTranche1 = [1653760800, 1656439200, 1659031200, 1661709600]; 
	//will only have 1 date of 5/28
	uint[] vestingTranche2 = [1653760800];
	//vests from 6/28/22 to 5/28/23
	uint[] vestingSeed = [
						1656439200,
						1659031200,
						1661709600,
						1664388000,
						1666980000,
						1669662000,
						1672254000,
						1674932400,
						1677610800,
						1680026400,
						1682704800,
						1685296800
	]; 
	//vests from 9/28/22 to 8/28/24
	uint[] vestingCorporate = [
						1664388000,
						1666980000,
						1669662000,
						1672254000,
						1674932400,
						1677610800,
						1680026400,
						1682704800,
						1685296800,
						1687975200,
						1690567200,
						1693245600,
						1695924000,
						1698516000,
						1701198000,
						1703790000,
						1706468400,
						1709146800,
						1711648800,
						1714327200,
						1716919200,
						1719597600,
						1722189600,
						1724868000
	]; 
	address lumerin = address(0x4b1D0b9F081468D780Ca1d5d79132b64301085d1);
	address owner;
	address titanMuSig = address(0x5846f9a299e78B78B9e4104b5a10E3915a0fAe3D);
	address bloqMuSig = address(0x6161eF0ce79322082A51b34Def2bCd0b0B8062d9);
	constructor () VestingWalletMulti(
		lumerin
	) {
		owner = msg.sender;
	}


	modifier onlyOwner{
		require(msg.sender == owner || msg.sender == titanMuSig || msg.sender == bloqMuSig, 'you are not authorized to call this function');
		_;
	}


	// add only owner modifier
	function setAddAddressToVestingSchedule(address _claiment, uint8 _vestingMonths, uint _vestingAmount) public onlyOwner{
		_erc20VestingAmount[_claiment] = _vestingAmount;
		_erc20Released[_claiment] = 0;
		_whichVestingSchedule[_claiment] = _vestingMonths;
		_isVesting[_claiment] = false;
	}

	function setAddMultiAddressToVestingSchedule(address[] memory _claiment, uint8[] memory _vestingMonths, uint[] memory _vestingAmount) public onlyOwner{
		for (uint i = 0; i < _claiment.length; i++) {
			setAddAddressToVestingSchedule(_claiment[i], _vestingMonths[i], _vestingAmount[i]);
		}
	}

	function Claim() public {
		release();
	}

	function _vestingSchedule(uint256 _totalAllocation, uint64 timestamp) internal view override returns(uint256) {
		require(_isVesting[msg.sender] == false, "vesting in progress");
		uint[] memory tempVesting;
		//determening which vesting array to use
		if (_whichVestingSchedule[msg.sender] == 1) {
			tempVesting = vestingTranche1;
		} else if (_whichVestingSchedule[msg.sender] == 2){
			tempVesting = vestingTranche2;
		} else if (_whichVestingSchedule[msg.sender] == 3){
			tempVesting = vestingSeed;
		} else if (_whichVestingSchedule[msg.sender] == 4){
			tempVesting = vestingCorporate;
		}
		if (timestamp < tempVesting[0]) {
			return 0;
		} else if (timestamp >= tempVesting[tempVesting.length-1]) {
			return _totalAllocation;
		} else {
			//modifying to use the ratio of months passed instead of a slow drip
			uint currentMonthTemp = 0;
			while (currentMonthTemp < tempVesting.length && timestamp >= tempVesting[currentMonthTemp]) {
				currentMonthTemp++;
			}
			return
				(_totalAllocation *
					currentMonthTemp) /
				tempVesting.length;
		}
	}


	//administrative functions

	//used to ensure lumerin can't be locked up in the contract
	function transferLumerinOut(address _recipient, uint _value) public onlyOwner{
		SafeERC20.safeTransfer(IERC20(lumerin), _recipient, _value);
	}

	function zeroOutClaimentValues(address _claiment) public onlyOwner{
		_erc20VestingAmount[_claiment] = 0;
		_erc20Released[_claiment] = 0;
	}

	function obtainVestingInformation(address _claiment) public view returns (uint256[2] memory) {
		//index 0 returns the claimable amount
		//index 1 returns the value remaining to be vested
		uint256 releaseableAmount = vestedAmount(_claiment, uint64(block.timestamp)) - released();
		uint256 remaining = _erc20VestingAmount[_claiment] - _erc20Released[_claiment];
		uint256[2] memory data = [releaseableAmount,remaining];
		return data;
	}
}

