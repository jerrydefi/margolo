// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

contract SimplePositionStorage {
    bytes32 private constant SIMPLE_POSITION_STORAGE_LOCATION = keccak256('folding.simplePosition.storage');

    /**
     * platform:        address of the underlying platform (AAVE, COMPOUND, etc) 底层平台地址（AAVE、COMPOUND等）
     *
     * supplyToken:     address of the token that is being supplied to the underlying platform 提供给底层平台的代币地址
     *                  This token is also the principal token 此token也是本金token
     *
     * borrowToken:     address of the token that is being borrowed to leverage on supply token 借用代币以利用供应代币的地址
     *
     * principalValue:  amount of supplyToken that user has invested in this position 用户在此仓位投资的supplyToken数量
     */
    struct SimplePositionStore {
        address platform;
        address supplyToken;
        address borrowToken;
        uint256 principalValue;
    }

    function simplePositionStore() internal pure returns (SimplePositionStore storage s) {
        bytes32 position = SIMPLE_POSITION_STORAGE_LOCATION;
        assembly {
            s_slot := position
        }
    }

    function isSimplePosition() internal view returns (bool) {
        return simplePositionStore().platform != address(0);
    }

    function requireSimplePositionDetails(
        address platform,
        address supplyToken,
        address borrowToken
    ) internal view {
        require(simplePositionStore().platform == platform, 'SP2');
        require(simplePositionStore().supplyToken == supplyToken, 'SP3');
        require(simplePositionStore().borrowToken == borrowToken, 'SP4');
    }
}