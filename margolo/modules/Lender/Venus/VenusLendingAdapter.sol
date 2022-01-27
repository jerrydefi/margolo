// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import './IComptroller.sol';
import './IVToken.sol';
import './IVEther.sol';
import './IVenusPriceOracle.sol';
import '../ILendingPlatform.sol';
import '../../../core/interfaces/ICTokenProvider.sol';
import '../../../../libraries/IWETH.sol';
import '../../../../libraries/Uint2Str.sol';

contract VenusLendingAdapter is ILendingPlatform, Uint2Str {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IWETH public immutable WETH; //0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    ICTokenProvider public immutable cTokenProvider;

    uint256 private constant BLOCKS_PER_YEAR = 365 * 24 * 60 * 20;
    uint256 private constant MANTISSA = 1e18;

    constructor(address wethAddress, address cTokenProviderAddress) public {
        require(wethAddress != address(0), 'ICP0');
        require(cTokenProviderAddress != address(0), 'ICP0');
        WETH = IWETH(wethAddress);
        cTokenProvider = ICTokenProvider(cTokenProviderAddress);
    }

    // Maps a token to its corresponding cToken
    function getVToken(address platform, address token) private view returns (address) {
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

            uint256 borrowBalance = IVToken(asset).borrowBalanceCurrent(address(this));
            uint256 supplyBalance = IVToken(asset).balanceOfUnderlying(address(this));

            // Get collateral factor for this asset
            (, uint256 collateralFactor, ) = IComptroller(platform).markets(asset);

            // Get the normalized price of the asset
            uint256 oraclePrice = IVenusPriceOracle(priceOracle).getUnderlyingPrice(asset);

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
        (, collateralFactor, ) = IComptroller(platform).markets(getVToken(platform, asset));
    }

    /// @dev Compound returns reference prices with regard to USD scaled by 1e18. Decimals disparity is taken into account
    function getReferencePrice(address platform, address token) public override returns (uint256) {
        address vToken = getVToken(platform, token);

        address priceOracle = IComptroller(platform).oracle();
        uint256 oraclePrice = IVenusPriceOracle(priceOracle).getUnderlyingPrice(vToken);
        return oraclePrice;
    }

    function getBorrowBalance(address platform, address token) external override returns (uint256 borrowBalance) {
        return IVToken(getVToken(platform, token)).borrowBalanceCurrent(address(this));
    }

    function getSupplyBalance(address platform, address token) external override returns (uint256 supplyBalance) {
        return IVToken(getVToken(platform, token)).balanceOfUnderlying(address(this));
    }

    function claimRewards(address platform) public override returns (address rewardsToken, uint256 rewardsAmount) {
        rewardsToken = IComptroller(platform).getXVSAddress();
        rewardsAmount = IERC20(rewardsToken).balanceOf(address(this));

        IComptroller(platform).claimVenus(address(this));

        rewardsAmount = IERC20(rewardsToken).balanceOf(address(this)).sub(rewardsAmount);
    }

    function enterMarkets(address platform, address[] calldata markets) external override {
        address[] memory vTokens = new address[](markets.length);
        for (uint256 i = 0; i < markets.length; i++) {
            vTokens[i] = getVToken(platform, markets[i]);
        }
        uint256[] memory results = IComptroller(platform).enterMarkets(vTokens);
        for (uint256 i = 0; i < results.length; i++) {
            require(results[i] == 0, buildErrorMessage('CFLA1', results[i]));
        }
    }

    function supply(
        address platform,
        address token,
        uint256 amount
    ) external override {
        address vToken = getVToken(platform, token);

        if (token == address(WETH)) {
            WETH.withdraw(amount);
            IVEther(vToken).mint{ value: amount }();
        } else {
            IERC20(token).safeIncreaseAllowance(vToken, amount);
            uint256 result = IVToken(vToken).mint(amount);
            require(result == 0, buildErrorMessage('CFLA2', result));
        }
    }

    function borrow(
        address platform,
        address token,
        uint256 amount
    ) external override {
        address vToken = getVToken(platform, token);

        uint256 result = IVToken(vToken).borrow(amount);
        require(result == 0, buildErrorMessage('CFLA3', result));

        if (token == address(WETH)) {
            WETH.deposit{ value: amount }();
        }
    }

    function redeemSupply(
        address platform,
        address token,
        uint256 amount
    ) external override {
        address vToken = address(getVToken(platform, token));

        uint256 result = IVToken(vToken).redeemUnderlying(amount);
        require(result == 0, buildErrorMessage('CFLA4', result));

        if (token == address(WETH)) {
            WETH.deposit{ value: amount }();
        }
    }

    function repayBorrow(
        address platform,
        address token,
        uint256 amount
    ) external override {
        address vToken = address(getVToken(platform, token));

        if (token == address(WETH)) {
            WETH.withdraw(amount);
            IVEther(vToken).repayBorrow{ value: amount }();
        } else {
            IERC20(token).safeIncreaseAllowance(vToken, amount);
            uint256 result = IVToken(vToken).repayBorrow(amount);
            require(result == 0, buildErrorMessage('CFLA5', result));
        }
    }

    function getAssetMetadata(address platform, address asset)
        external
        override
        returns (AssetMetadata memory assetMetadata)
    {
        address vToken = getVToken(platform, asset);

        (, uint256 collateralFactor, ) = IComptroller(platform).markets(vToken);
        uint256 estimatedCompPerYear = IComptroller(platform).venusSpeeds(vToken).mul(BLOCKS_PER_YEAR);
        address rewardTokenAddress = IComptroller(platform).getXVSAddress();

        assetMetadata.assetAddress = asset;
        assetMetadata.assetSymbol = ERC20(asset).symbol();
        assetMetadata.assetDecimals = ERC20(asset).decimals();
        assetMetadata.referencePrice = IVenusPriceOracle(IComptroller(platform).oracle()).getUnderlyingPrice(vToken);
        assetMetadata.totalLiquidity = IVToken(vToken).getCash();
        assetMetadata.totalSupply = IVToken(vToken).totalSupply().mul(IVToken(vToken).exchangeRateCurrent()) / MANTISSA;
        assetMetadata.totalBorrow = IVToken(vToken).totalBorrowsCurrent();
        assetMetadata.totalReserves = IVToken(vToken).totalReserves();
        assetMetadata.supplyAPR = IVToken(vToken).supplyRatePerBlock().mul(BLOCKS_PER_YEAR);
        assetMetadata.borrowAPR = IVToken(vToken).borrowRatePerBlock().mul(BLOCKS_PER_YEAR);
        assetMetadata.rewardTokenAddress = rewardTokenAddress;
        assetMetadata.rewardTokenDecimals = ERC20(rewardTokenAddress).decimals();
        assetMetadata.rewardTokenSymbol = ERC20(rewardTokenAddress).symbol();
        assetMetadata.estimatedSupplyRewardsPerYear = estimatedCompPerYear;
        assetMetadata.estimatedBorrowRewardsPerYear = estimatedCompPerYear;
        assetMetadata.collateralFactor = collateralFactor;
        assetMetadata.liquidationFactor = collateralFactor;
        assetMetadata.canSupply = !IComptroller(platform).mintGuardianPaused(vToken);
        assetMetadata.canBorrow = !IComptroller(platform).borrowGuardianPaused(vToken);
    }

    /// @dev This receive function is only needed to allow for unit testing this connector.
    receive() external payable {}
}