// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import './IVToken.sol';

interface IComptroller {
    /**
     * @notice Marker function used for light validation when updating the comptroller of a market
     * @dev Implementations should simply return true.
     * @return true
     */
    function isComptroller() external view returns (bool);

    function oracle() external view returns (address);

    // @notice get platform token address for reward
    function getXVSAddress() external view returns (address);

    /*** Assets You Are In ***/

    function getAssetsIn(address account) external view returns (address[] memory);

    function enterMarkets(address[] calldata vTokens) external returns (uint256[] memory);

    function exitMarket(address vToken) external returns (uint256);

    function markets(address vTokenAddress)
        external
        view
        returns (
            bool,
            uint256,
            bool
        );

    function getAllMarkets() external view returns (address[] memory);

    function borrowGuardianPaused(address) external view returns (bool);

    function mintGuardianPaused(address) external view returns (bool);

    /*** Policy Hooks ***/

    function mintAllowed(
        address vToken,
        address minter,
        uint256 mintAmount
    ) external returns (uint256);

    function mintVerify(
        address vToken,
        address minter,
        uint256 mintAmount,
        uint256 mintTokens
    ) external;

    function redeemAllowed(
        address vToken,
        address redeemer,
        uint256 redeemTokens
    ) external returns (uint256);

    function redeemVerify(
        address vToken,
        address redeemer,
        uint256 redeemAmount,
        uint256 redeemTokens
    ) external;

    function borrowAllowed(
        address vToken,
        address borrower,
        uint256 borrowAmount
    ) external returns (uint256);

    function borrowVerify(
        address vToken,
        address borrower,
        uint256 borrowAmount
    ) external;

    function repayBorrowAllowed(
        address vToken,
        address payer,
        address borrower,
        uint256 repayAmount
    ) external returns (uint256);

    function repayBorrowVerify(
        address vToken,
        address payer,
        address borrower,
        uint256 repayAmount,
        uint256 borrowerIndex
    ) external;

    function liquidateBorrowAllowed(
        address vTokenBorrowed,
        address vTokenCollateral,
        address liquidator,
        address borrower,
        uint256 repayAmount
    ) external returns (uint256);

    function liquidateBorrowVerify(
        address vTokenBorrowed,
        address vTokenCollateral,
        address liquidator,
        address borrower,
        uint256 repayAmount,
        uint256 seizeTokens
    ) external;

    function seizeAllowed(
        address vTokenCollateral,
        address vTokenBorrowed,
        address liquidator,
        address borrower,
        uint256 seizeTokens
    ) external returns (uint256);

    function seizeVerify(
        address vTokenCollateral,
        address vTokenBorrowed,
        address liquidator,
        address borrower,
        uint256 seizeTokens
    ) external;

    function transferAllowed(
        address vToken,
        address src,
        address dst,
        uint256 transferTokens
    ) external returns (uint256);

    function transferVerify(
        address vToken,
        address src,
        address dst,
        uint256 transferTokens
    ) external;

    /*** Liquidity/Liquidation Calculations ***/

    function getAccountLiquidity(address account)
        external
        view
        returns (
            uint256,
            uint256,
            uint256
        );

    function liquidateCalculateSeizeTokens(
        address vTokenBorrowed,
        address vTokenCollateral,
        uint256 repayAmount
    ) external view returns (uint256, uint256);

    function getHypotheticalAccountLiquidity(
        address account,
        address vTokenModify,
        uint256 redeemTokens,
        uint256 borrowAmount
    )
        external
        view
        returns (
            uint256,
            uint256,
            uint256
        );

    /*** Rewards ***/

    function venusSpeeds(address vToken) external view returns (uint256);

    function claimVenus(address holder) external;

    /*** Admin ***/

    function admin() external view returns (address);

}