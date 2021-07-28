// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVaultController {
    // function minter() external view returns (address);
    // function bunnyChef() external view returns (address);
    function stakingToken() external view returns (address);
}