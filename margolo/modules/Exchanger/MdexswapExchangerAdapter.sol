// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import './IExchanger.sol';
import './UniswapExchangerAdapter.sol';

contract MdexswapExchangerAdapter is IExchanger, UniswapExchangerAdapter {
    constructor(address _router) public UniswapExchangerAdapter(_router) {}
}