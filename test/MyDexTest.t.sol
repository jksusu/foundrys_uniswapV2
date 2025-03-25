// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {MyDex} from "../src/MyDex.sol";
import {RntToken} from "../src/RntToken.sol";
import {UniswapV2Factory} from "../src/uniswap/UniswapV2Factory.sol";
import {UniswapV2Router} from "../src/uniswap/UniswapV2Router.sol";
import {UniswapV2Pair} from "../src/uniswap/UniswapV2Pair.sol";
import {WETH} from "../src/WETH.sol";

contract MyDexTest is Test {
    address owner;
    uint256 ownerPrivateKey;

    address liquidityUser1;
    uint256 liquidityUser1Key;

    address lpAddress; //lp持有者地址

    address user1Address;
    address user2Address;

    UniswapV2Factory uniswapFatory;
    UniswapV2Router uniswapRouter;
    WETH weth;

    RntToken rntToken;
    MyDex myDex;

    address PAIR; //交易对

    uint256 RntAmount = 1000000000000000000;
    uint256 EthAmount = 100 ether;

    // 初始化设置
    function setUp() public {
        //获取交易对合约的创建hash 需要使用这里得到的hash替换 UniswapV2Library 合约中 pairFor 函数的 hex 值；否则会导致流动性添加失败
        bytes memory bytecode = type(UniswapV2Pair).creationCode;
        bytes32 hash = keccak256(bytecode);
        console.logBytes32(hash);

        //设置本地测试链执行
        vm.createSelectFork("http://127.0.0.1:8545");

        lpAddress = makeAddr("lpAddress");
        user1Address = makeAddr("user1Address");
        user2Address = makeAddr("user2Address");
        (owner, ownerPrivateKey) = makeAddrAndKey("owner"); //管理员
        (liquidityUser1, liquidityUser1Key) = makeAddrAndKey("liquidityUser1"); //流动性添加者

        vm.startPrank(owner);
        //部署工厂合约
        uniswapFatory = new UniswapV2Factory(liquidityUser1);
        //部署WETH代币合约
        weth = new WETH();
        //部署路由合约
        uniswapRouter = new UniswapV2Router(address(uniswapFatory), address(weth));
        //如果需要前端还需要部署 mmulticall 合约

        console.log("uniswapFatoryAddress:", address(uniswapFatory));
        console.log("wethAddress:", address(weth));
        console.log("uniswapRouterAddress:", address(uniswapRouter));

        rntToken = new RntToken();
        console.log("rntTokenAddress:", address(rntToken));

        //部署交易所合约
        myDex = new MyDex(address(uniswapFatory), address(uniswapRouter), address(weth), address(rntToken));
        console.log("myDexAddress:", address(myDex));

        // 给 liquidityUser1 转 eth
        vm.deal(liquidityUser1, EthAmount);
        assertEq(address(liquidityUser1).balance, EthAmount);
        // 给发送者添加 rnt代币
        rntToken.transfer(liquidityUser1, RntAmount);
        rntToken.transfer(user2Address, 10000000000);
        assertEq(rntToken.balanceOf(liquidityUser1), RntAmount);

        //添加流动性
        addLiquidity();

        vm.stopPrank();
    }

    //测试流动性添加
    function addLiquidity() public {
        vm.startPrank(liquidityUser1);

        //创建交易对
        PAIR = myDex.createEthPair(address(rntToken));
        console.log("PAIR:", PAIR);

        //授权代币给 router 合约
        rntToken.approve(address(uniswapRouter), rntToken.balanceOf(liquidityUser1));

        uint256 slippageBps = 50; //设置滑点 0.5%
        uint256 amountTokenDesired = RntAmount; //添加池子的代币数
        uint256 amountETH = EthAmount; //添加池子的eth数
        uint256 amountTokenMin = (amountTokenDesired * (10000 - slippageBps)) / 10000;
        uint256 amountETHMin = (amountETH * (10000 - slippageBps)) / 10000;
        uint256 deadline = block.timestamp + 1000;

        (uint256 _amountToken, uint256 _amountETH, uint256 _liquidity) = uniswapRouter.addLiquidityETH{value: amountETH}(
            address(rntToken), amountTokenDesired, amountTokenMin, amountETHMin, lpAddress, deadline
        );
        assert(_liquidity > 0);
        console.log("amountToken:", _amountToken);
        console.log("amountETH:", _amountETH);
        console.log("liquidity:", _liquidity);
        assertEq(_amountToken, amountTokenDesired);
        assertEq(_amountETH, amountETH);

        //获取池子余额
        (uint256 reserve0, uint256 reserve1,) = UniswapV2Pair(PAIR).getReserves();
        console.log("reserve0:", reserve0);
        console.log("reserve1:", reserve1);
        //验证是否和添加的一样
        assertEq(reserve0, amountTokenDesired);
        assertEq(reserve1, amountETH);

        //计算初始价格
        uint256 initPrice = amountTokenDesired / 10;
        console.log("initPrice:", initPrice);
        vm.stopPrank();
    }

    function testSwapETHForRNT() public {
        vm.startPrank(user1Address);
        uint256 user1EthAmount = 1 ether;
        vm.deal(user1Address, user1EthAmount);
        assertEq(address(user1Address).balance, user1EthAmount);
        myDex.swapETHForRNT{value: user1EthAmount}();
        assert(rntToken.balanceOf(user1Address) > 0);

        console.log("user1Address rnt balance:", rntToken.balanceOf(user1Address));
        console.log("user1Address eth balance:", address(user1Address).balance);
        vm.stopPrank();
    }

    function testSwapRNTForETH() public {
        vm.startPrank(user2Address);
        assert(rntToken.balanceOf(user2Address) > 0);
        console.log("user2Address rnt balance:", rntToken.balanceOf(user2Address));

        rntToken.approve(address(myDex), rntToken.balanceOf(user2Address));
        // rntToken.approve(address(uniswapRouter), rntToken.balanceOf(user2Address));

        myDex.swapRNTForETH(rntToken.balanceOf(user2Address));
        assert(rntToken.balanceOf(user2Address) == 0);
        assert(address(user2Address).balance > 0);
        console.log("user2Address rnt balance:", rntToken.balanceOf(user2Address));
        console.log("user2Address eth balance:", address(user2Address).balance);
        vm.stopPrank();
    }

    function testRemoveLiquidityETHViaDex() public {
        vm.startPrank(lpAddress);

        uint256 liquidity = UniswapV2Pair(PAIR).balanceOf(lpAddress);
        console.log("liquidity balance:", liquidity);
        assert(liquidity > 0);

        UniswapV2Pair(PAIR).approve(address(myDex), liquidity);

        (uint256 amountToken, uint256 amountETH) =
            myDex.removeLiquidityETH(liquidity, 0, 0, lpAddress, block.timestamp + 1000);
        console.log("amountToken:", amountToken);
        console.log("amountETH:", amountETH);

        //检查 lp流动性余额是否为 0
        assertEq(UniswapV2Pair(PAIR).balanceOf(lpAddress), 0);

        vm.stopPrank();
    }
}
