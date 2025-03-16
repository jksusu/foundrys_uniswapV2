// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IUniswapV2Router} from "./uniswap/interfaces/IUniswapV2Router.sol";
import {IUniswapV2Factory} from "./uniswap/interfaces/IUniswapV2Factory.sol";
import {UniswapV2Library} from "./uniswap/libraries/UniswapV2Library.sol";
import {IWETH} from "./uniswap/interfaces/IWETH.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MyDex {
    IUniswapV2Router public immutable uniswapRouter;
    IUniswapV2Factory public immutable uniswapFactory;
    IWETH public immutable weth;
    IERC20 public immutable rntToken;

    constructor(
        address factory,
        address router,
        address _weth,
        address _rntToken
    ) {
        uniswapRouter = IUniswapV2Router(router);
        uniswapFactory = IUniswapV2Factory(factory);
        weth = IWETH(_weth);
        rntToken = IERC20(_rntToken);
    }

    receive() external payable {}

    //创建eth交易对
    function createEthPair(address token) external returns (address pair) {
        return uniswapFactory.createPair(address(weth), token);
    }

    //使用eth兑换rnt
    function swapETHForRNT() external payable {
        address[] memory path = new address[](2);
        path[0] = uniswapRouter.WETH();
        path[1] = address(rntToken);

        uniswapRouter.swapExactETHForTokens{value: msg.value}(
            0,
            path,
            msg.sender,
            block.timestamp + 1000
        );
    }


    function swapRNTForETH(uint256 rntAmount) external {
        require(rntToken.transferFrom(msg.sender, address(this), rntAmount), "Transfer failed");
        address[] memory path = new address[](2);
        path[0] = address(rntToken);
        path[1] = uniswapRouter.WETH();
        //当前合约授权给 router
        rntToken.approve(address(uniswapRouter), rntAmount);
        
        uniswapRouter.swapExactTokensForETH(
            rntAmount,
            0,
            path,
            msg.sender,
            block.timestamp + 1000
        );
    }
}
