// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockERC721 is ERC721 {
    constructor(
        string memory name,
        string memory symbol,
        uint256 supply
    ) public ERC721(name, symbol) {}
}