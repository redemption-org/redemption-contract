// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

interface IPWSocialCard {
    function daoMint(address to) external returns(uint256);

    function daoBurn(uint256 tokenId) external returns(bool);
}