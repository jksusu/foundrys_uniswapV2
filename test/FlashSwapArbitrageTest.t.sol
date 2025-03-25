// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {WETH} from "../src/WETH.sol";
import {ERC20TOKEN} from "../src/ERC20TOKEN.sol";
import {UniswapV2Factory} from "../src/uniswap/UniswapV2Factory.sol";
import {UniswapV2Router} from "../src/uniswap/UniswapV2Router.sol";
import {UniswapV2Pair} from "../src/uniswap/UniswapV2Pair.sol";
import {FlashSwapArbitrage} from "../src/FlashSwapArbitrage.sol";

contract FlashSwapArbitrageTest is Test {
    address owner;
    uint256 ownerPrivateKey;

    address liquidityUser1;
    uint256 liquidityUser1Key;

    address lpAddress; //lp持有者地址

    address user1Address;
    address user2Address;

    UniswapV2Factory uniswapFatory;
    UniswapV2Router uniswapRouter;

    FlashSwapArbitrage flashSwap;

    //三个池子 a/weth b/weth a/b
    WETH weth;
    ERC20TOKEN AToken;
    ERC20TOKEN BToken;

    address PAIR; //交易对

    uint256 TokenAmount = 1e18; //每个池子里面有 1
    uint256 EthAmount = 100 ether; //池子里面有 100个 eth

    // 初始化设置
    function setUp() public {
        // 获取交易对合约的创建hash 需要使用这里得到的hash替换 UniswapV2Library 合约中 pairFor 函数的 hex 值；否则会导致流动性添加失败
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
        weth = new WETH();
        uniswapFatory = new UniswapV2Factory(liquidityUser1);
        uniswapRouter = new UniswapV2Router(address(uniswapFatory), address(weth));
        console.log("wethAddress:", address(weth));
        console.log("uniswapFatoryAddress:", address(uniswapFatory));
        console.log("uniswapRouterAddress:", address(uniswapRouter));

        //增加token
        AToken = new ERC20TOKEN("A", "A");
        BToken = new ERC20TOKEN("B", "B");
        console.log("A:", address(AToken));
        console.log("B:", address(BToken));

        //部署套利合约
        flashSwap = new FlashSwapArbitrage(address(uniswapFatory), address(uniswapRouter));
        console.log("flashSwapArbitrageAddress:", address(flashSwap));

        // 给 liquidityUser1 转 eth
        vm.deal(liquidityUser1, EthAmount);
        assertEq(address(liquidityUser1).balance, EthAmount);
        // 给发送者添加 rnt代币
        AToken.transfer(liquidityUser1, TokenAmount);
        AToken.transfer(address(flashSwap), TokenAmount);
        BToken.transfer(liquidityUser1, TokenAmount);
        AToken.transfer(user2Address, 10000000000);
        BToken.transfer(user2Address, 10000000000);
        assertEq(AToken.balanceOf(liquidityUser1), TokenAmount);
        assertEq(BToken.balanceOf(liquidityUser1), TokenAmount);

        addLiquidity(); //创建交易对，添加流动性

        vm.stopPrank();
    }
    //添加流动性

    function addLiquidity() public {
        vm.deal(liquidityUser1, 10000 ether);
        vm.startPrank(liquidityUser1);

        console.log("liquidityUser1:", address(liquidityUser1).balance);

        //创建交易对
        address APair = uniswapFatory.createPair(address(AToken), address(weth));
        console.log("APair:", APair);
        address BPair = uniswapFatory.createPair(address(BToken), address(weth));
        console.log("BPair:", BPair);
        address ABPair = uniswapFatory.createPair(address(AToken), address(BToken));
        console.log("ABPair:", ABPair);

        //授权代币给 router 合约
        AToken.approve(address(uniswapRouter), type(uint256).max);
        BToken.approve(address(uniswapRouter), type(uint256).max);
        weth.approve(address(uniswapRouter), type(uint256).max);

        // uint256 slippageBps = 50; //设置滑点 0.5%
        uint256 tokenAmount = 10000000000; //初次添加不用设置滑点
        uint256 deadline = block.timestamp + 1000;

        // 添加 A/ETH 流动性
        (,, uint256 liquidityA) =
            uniswapRouter.addLiquidityETH{value: EthAmount}(address(AToken), tokenAmount, 0, 0, lpAddress, deadline);
        // 添加 B/ETH 流动性
        (,, uint256 liquidityB) =
            uniswapRouter.addLiquidityETH{value: EthAmount}(address(BToken), tokenAmount, 0, 0, lpAddress, deadline);
        // 添加 A/B 流动性
        (,, uint256 liquidityAB) = uniswapRouter.addLiquidity(
            address(AToken), address(BToken), 100000000, 100000000, 10000000, 10000000, lpAddress, deadline
        );
        // 验证流动性添加是否成功
        require(liquidityA > 0 && liquidityB > 0 && liquidityAB > 0, "Add liquidity failed");

        // 获取并打印各个池子的储备量
        (uint256 reserveA0, uint256 reserveA1,) = UniswapV2Pair(APair).getReserves();
        (uint256 reserveB0, uint256 reserveB1,) = UniswapV2Pair(BPair).getReserves();
        (uint256 reserveAB0, uint256 reserveAB1,) = UniswapV2Pair(ABPair).getReserves();

        console.log("A/ETH Pool Reserves:", reserveA0, reserveA1);
        console.log("B/ETH Pool Reserves:", reserveB0, reserveB1);
        console.log("A/B Pool Reserves:", reserveAB0, reserveAB1);
        vm.stopPrank();

        vm.startPrank(owner);
        flashSwap.setPools(APair, BPair);
        vm.stopPrank();
    }

    function testStartArbitrage() public {
        vm.startPrank(owner);
        flashSwap.startArbitrage(address(AToken), 100, 0);
        vm.stopPrank();
    }
}
