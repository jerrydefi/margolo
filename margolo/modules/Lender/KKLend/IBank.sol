// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IBank {
    /**
     * @dev deposit and repay token to KKLend
     */
    function tokenIn(address token, uint256 amount) external payable;

    /**
     * @dev withdraw and borrow token from KKLend
     */
    function tokenOut(address token, uint256 amount) external;

    function flashloan(address receiver, address token, uint256 amount, bytes memory params) external;
}