// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

/// @dev Interface of the ERC20 standard as defined in the EIP.
interface IKKLendPriceOracle {
    function get(address token) external view returns (uint256);
}