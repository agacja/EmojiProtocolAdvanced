// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IChip {
    function mintFromEmojiProtocol(
        address to,
        uint256 quantity,
        uint256 tokenId,
        address feeRecipient
    ) external payable;
    function burn(address from, uint256 tokenId, uint256 quantity) external;
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function withdraw(uint96 money) external;
    function getOwnerTokens(address owner) external view returns (uint256);
    function getLowestTokenPriceForOwner(address owner) external view returns (uint256 lowestTokenId, uint96 price);
    function getspinFee() external view returns (uint16);
   
  }