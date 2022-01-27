// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IFEther {
    function mint(address account, uint256 mintAmount) external returns (bytes memory);

    function withdraw(address payable withdrawer, uint256 withdrawTokensIn, uint256 withdrawAmountIn) external returns (uint256);

    function borrow(address borrower, uint256 borrowAmount) external returns (bytes memory);

    function repay(address borrower, uint256 repayAmount) external returns (uint256);

    function exchangeRateCurrent() external returns (uint256);

    function borrowBalanceCurrent(address account) external returns (uint256);

    function borrowBalanceStored(address account) external view returns (uint256);

    function balanceOfUnderlying(address account) external returns (uint256);

    function getAccountState(address account) external view returns (uint256, uint256, uint256, uint256);

    function accrueInterest() external returns (uint256);

    function underlying() external view returns (address);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256 balance);

    function allowance(address, address) external view returns (uint256);

    function approve(address, uint256) external returns (bool);

    function transfer(address, uint256) external returns (bool);

    function transferFrom(address, address, uint256) external returns (bool);
}