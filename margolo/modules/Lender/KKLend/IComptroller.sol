// SPDX-License-Identifier: MIT

// Taken from: https://github.com/studydefi/money-legos/blob/abae7f0c2be3bb32a820ca182433872570037042/src/compound/contracts/IComptroller.sol

pragma solidity 0.6.12;

import './IFToken.sol';

interface IComptroller {
    function oracle() external view returns (address);

//    function getCompAddress() external view returns (address);

    /*** Assets You Are In ***/
    function markets(address token) external view returns (address, bool, uint256, uint256);

    function getAllMarkets() external view returns (address[] memory);

    function isFTokenValid(address fToken) external view returns (bool);

    /*** Policy Hooks ***/

    function getAccountLiquidity(address account) external view returns (uint256, uint256);

    /*
     * @return fTokenAddress list of account has entered
     */
    function getAssetsIn(address account) external view returns (address[] memory);

    /*** Liquidity/Liquidation Calculations ***/

    function liquidateTokens(
        address fTokenBorrowed,
        address fTokenCollateral,
        uint256 actualRepayAmount
    ) external view returns (uint256);

    /*
     * @return sumCollaterals,sumBorrows
     * Compared with 'getHypotheticalAccountLiquidity', need to implement the following operations yourself
     *   if (sumCollaterals > sumBorrows) {
     *       return (sumCollaterals - sumBorrows, 0);
     *   } else {
     *       return (0, sumBorrows - sumCollaterals);
     *   }
     */
    function getUserLiquidity(
        address account,
        address fTokenModify,
        uint256 redeemTokens,
        uint256 borrowAmount
    ) external view returns (uint256, uint256);

//    /*** Rewards ***/
//
//    function compSpeeds(address cToken) external view returns (uint256);
//
//    function claimComp(address holder) external;

    /*** Admin ***/

    function admin() external view returns (address);

    /*** Flash Loan ***/
    function flashloanFeeBips() external view returns (uint256);

    function flashloanVault() external view returns (address);

    function transferFlashloanAsset(address token, address payable user, uint256 amount) external;

}