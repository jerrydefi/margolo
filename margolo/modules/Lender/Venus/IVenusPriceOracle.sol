// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

/// @dev Interface of the ERC20 standard as defined in the EIP.
// VenusChainlinkOracle
// VenusPriceOracle
interface IVenusPriceOracle {
    function getUnderlyingPrice(address vToken) external view returns (uint256);
}