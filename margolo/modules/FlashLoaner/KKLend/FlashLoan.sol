// SPDX-License-Identifier: MIT

pragma solidity ^0.6.6;
pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import "./IFlashLoanReceiver.sol";
import "../../Lender/KKLend/IBank.sol";
import "../../Lender/KKLend/IComptroller.sol";
import '../../../modules/FoldingAccount/FoldingAccountStorage.sol';

abstract contract FlashLoan is IFlashLoanReceiver, FoldingAccountStorage {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public immutable SELF_ADDRESS;
    address public immutable BANK;
    address public immutable BANK_CONTROLLER;

    constructor(address bankAddress, address controllerAddress) public {
        require(bankAddress != address(0), 'IFL0');
        require(controllerAddress != address(0), 'IFL1');
        SELF_ADDRESS = address(this);
        BANK = bankAddress;
        BANK_CONTROLLER = controllerAddress;
    }

    struct LoanData {
        address loanedToken;
        uint256 loanAmount;
        uint256 repayAmount;
        bytes data;
    }

    /**
        This function is called after your contract has received the flash loaned amount
     */
    function executeOperation(
        address _reserve,
        uint256,
        uint256,
        bytes calldata _params
    ) external override {
        require(address(msg.sender) == BANK, 'KFM1');
        require(aStore().callbackTarget == SELF_ADDRESS, 'KFM2');

        // Clear forced callback to this connector
        // only flashloan use
        delete aStore().callbackTarget;
        delete aStore().expectedCallbackSig;

        LoanData memory loanData = abi.decode(_params, (LoanData));
        require(_reserve == loanData.loanedToken, "KFM3");

        useFlashLoan(loanData.loanedToken, loanData.loanAmount, loanData.repayAmount, loanData.data);
    }

    function getFlashLoan(
        address tokenToLoan,
        uint256 flashLoanAmount,
        bytes memory data
    ) internal {
        uint256 fee = flashLoanAmount.mul(IComptroller(BANK_CONTROLLER).flashloanFeeBips()).div(10000);
        uint256 repayAmount = flashLoanAmount.add(fee);

        bytes memory loanData = abi.encode(
            LoanData({
                loanedToken: tokenToLoan,
                loanAmount: flashLoanAmount,
                repayAmount: repayAmount,
                data: data
            })
        );

        // Force callback to this connector -- account delegatecall this connector
        // like addImplementation on registry
        aStore().callbackTarget = SELF_ADDRESS;
        aStore().expectedCallbackSig = bytes4(keccak256('executeOperation(address,uint256,uint256,bytes)'));

        IERC20(tokenToLoan).safeIncreaseAllowance(BANK_CONTROLLER, repayAmount);
        // 此处address(this)为account合约地址 -- delegatecall
        IBank(BANK).flashloan(address(this), tokenToLoan, flashLoanAmount, loanData);
        IERC20(tokenToLoan).safeApprove(BANK_CONTROLLER, 0);
    }

    function useFlashLoan(
        address loanToken,
        uint256 loanAmount,
        uint256 repayAmount,
        bytes memory data
    ) internal virtual;
}