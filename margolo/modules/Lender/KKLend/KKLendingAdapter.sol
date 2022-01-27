// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import './IBank.sol';
import './IComptroller.sol';
import './IFToken.sol';
import './IFEther.sol';
import './IKKLendPriceOracle.sol';
import '../ILendingPlatform.sol';
import '../../../core/interfaces/ICTokenProvider.sol';
import '../../../../libraries/IWETH.sol';
import '../../../../libraries/Uint2Str.sol';

contract KKLendingAdapter is ILendingPlatform, Uint2Str {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IWETH public immutable WETH; //WBNB=0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    ICTokenProvider public immutable cTokenProvider;
    IBank public immutable Bank;

    address private constant MAIN_TOKEN = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    uint256 private constant BLOCKS_PER_YEAR = 365 * 24 * 60 * 20;
    uint256 private constant MANTISSA = 1e18;

    constructor(address wethAddress, address cTokenProviderAddress, address bankAddress) public {
        require(wethAddress != address(0), 'ICP0');
        require(cTokenProviderAddress != address(0), 'ICP0');
        require(bankAddress != address(0), 'ICP0');
        WETH = IWETH(wethAddress);
        cTokenProvider = ICTokenProvider(cTokenProviderAddress);
        Bank = IBank(bankAddress);
    }

    // Maps a token to its corresponding cToken
    function getFToken(address platform, address token) private view returns (address) {
        return cTokenProvider.getCToken(platform, token);
    }

    function buildErrorMessage(string memory message, uint256 code) private pure returns (string memory) {
        return string(abi.encodePacked(message, ': ', uint2str(code)));
    }

    function getCollateralUsageFactor(address platform) external override returns (uint256) {
        uint256 sumCollateral = 0;
        uint256 sumBorrows = 0;

        address priceOracle = IComptroller(platform).oracle();

        // For each asset the account is in
        address[] memory assets = IComptroller(platform).getAssetsIn(address(this));
        for (uint256 i = 0; i < assets.length; i++) {
            address asset = assets[i];

            uint256 borrowBalance = IFToken(asset).borrowBalanceCurrent(address(this));
            uint256 supplyBalance = IFToken(asset).balanceOfUnderlying(address(this));

            // Get collateral factor for this asset
            (, , uint256 collateralFactor, ) = IComptroller(platform).markets(asset);

            // Get the normalized price of the asset
            uint256 oraclePrice = IKKLendPriceOracle(priceOracle).get(IFToken(asset).underlying());

            // the collateral value will be price * collateral balance * collateral factor. Since
            // both oracle price and collateral factor are scaled by 1e18, we need to undo this scaling
            sumCollateral = sumCollateral.add(oraclePrice.mul(collateralFactor).mul(supplyBalance) / MANTISSA**2);
            sumBorrows = sumBorrows.add(oraclePrice.mul(borrowBalance) / MANTISSA);
        }
        if (sumCollateral > 0) return sumBorrows.mul(MANTISSA) / sumCollateral;
        return 0;
    }

    function getCollateralFactorForAsset(address platform, address asset)
        external
        override
        returns (uint256 collateralFactor)
    {
        (, , collateralFactor, ) = IComptroller(platform).markets(asset);
    }

    /// @dev Compound returns reference prices with regard to USD scaled by 1e18. Decimals disparity is taken into account
    function getReferencePrice(address platform, address token) public override returns (uint256) {
        address priceOracle = IComptroller(platform).oracle();
        uint256 oraclePrice = IKKLendPriceOracle(priceOracle).get(token);
        return oraclePrice;
    }

    function getBorrowBalance(address platform, address token) external override returns (uint256 borrowBalance) {
        return IFToken(getFToken(platform, token)).borrowBalanceCurrent(address(this));
    }

    function getSupplyBalance(address platform, address token) external override returns (uint256 supplyBalance) {
        return IFToken(getFToken(platform, token)).balanceOfUnderlying(address(this));
    }

    function claimRewards(address) public override returns (address rewardsToken, uint256 rewardsAmount) {
        rewardsToken = address(WETH);
        rewardsAmount = 0;
    }

    /// @dev Empty because not this in KKLend
    function enterMarkets(address, address[] memory markets) external override {}

    function supply(
        address platform,
        address token,
        uint256 amount
    ) external override {
        if (token == address(WETH)) {
            WETH.withdraw(amount);
            Bank.tokenIn{ value: amount }(MAIN_TOKEN, amount);
        } else {
            IERC20(token).safeIncreaseAllowance(platform, amount);
            Bank.tokenIn(token, amount);
        }
    }

    function borrow(
        address,
        address token,
        uint256 amount
    ) external override {
        if (token == address(WETH)) {
            Bank.tokenOut(MAIN_TOKEN, amount);
            WETH.deposit{ value: amount }();
        } else {
            Bank.tokenOut(token, amount);
        }
    }

    function redeemSupply(
        address,
        address token,
        uint256 amount
    ) external override {
        if (token == address(WETH)) {
            Bank.tokenOut(MAIN_TOKEN, amount);
            WETH.deposit{ value: amount }();
        } else {
            Bank.tokenOut(token, amount);
        }
    }

    function repayBorrow(
        address platform,
        address token,
        uint256 amount
    ) external override {
        if (token == address(WETH)) {
            WETH.withdraw(amount);
            Bank.tokenIn{ value: amount }(MAIN_TOKEN, amount);
        } else {
            IERC20(token).safeIncreaseAllowance(platform, amount);
            Bank.tokenIn(token, amount);
        }
    }

    function getAssetMetadata(address platform, address asset)
        external
        override
        returns (AssetMetadata memory assetMetadata)
    {
        address fToken = getFToken(platform, asset);

        (, , uint256 collateralFactor,) = IComptroller(platform).markets(asset);
        uint256 estimatedCompPerYear = 0;
        address rewardTokenAddress = address(WETH);

        assetMetadata.assetAddress = asset;
        assetMetadata.assetSymbol = ERC20(asset).symbol();
        assetMetadata.assetDecimals = ERC20(asset).decimals();
        assetMetadata.referencePrice = IKKLendPriceOracle(IComptroller(platform).oracle()).get(asset);
        assetMetadata.totalLiquidity = IFToken(fToken).totalCash();
        assetMetadata.totalSupply = IFToken(fToken).totalSupply().mul(IFToken(fToken).exchangeRateCurrent()) / MANTISSA;
        assetMetadata.totalBorrow = IFToken(fToken).totalBorrows();
        assetMetadata.totalReserves = IFToken(fToken).totalReserves();
        assetMetadata.supplyAPR = IFToken(fToken).getSupplyRate().mul(BLOCKS_PER_YEAR);
        assetMetadata.borrowAPR = IFToken(fToken).getBorrowRate().mul(BLOCKS_PER_YEAR);
        assetMetadata.rewardTokenAddress = rewardTokenAddress;
        assetMetadata.rewardTokenDecimals = ERC20(rewardTokenAddress).decimals();
        assetMetadata.rewardTokenSymbol = ERC20(rewardTokenAddress).symbol();
        assetMetadata.estimatedSupplyRewardsPerYear = estimatedCompPerYear;
        assetMetadata.estimatedBorrowRewardsPerYear = estimatedCompPerYear;
        assetMetadata.collateralFactor = collateralFactor;
        assetMetadata.liquidationFactor = collateralFactor;
        assetMetadata.canSupply = IComptroller(platform).isFTokenValid(fToken);
        assetMetadata.canBorrow = assetMetadata.canSupply;
    }

    /// @dev This receive function is only needed to allow for unit testing this connector.
    receive() external payable {}
}