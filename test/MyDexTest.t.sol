// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import { MyDex } from "../src/MyDex.sol";
import { RNT } from "../../src/dex/RNT.sol";

contract MyDexTest is Test {
    address owner;
    uint256 ownerPrivateKey;

    address liquidityUser1;
    uint256 liquidityUser1Key;

    RNT rnt;
    MyDex myDex;

    address weth = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512;
    address factory = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address router = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    // 初始化设置
    function setUp() public {
        vm.startPrank(owner);
        //设置本地测试链执行
        vm.createSelectFork("http://127.0.0.1:8545");
        (owner, ownerPrivateKey) = makeAddrAndKey("owner"); //管理员
        (liquidityUser1, liquidityUser1Key) = makeAddrAndKey("liquidityUser1"); //流动性添加者
        rnt = new RNT();
        myDex = new MyDex(factory, router, weth);

        // 给 liquidityUser1 转 eth
        vm.transfer(liquidityUser1, 100 ether);
        assertEq(vm.balanceOf(liquidityUser1), 100 ether);
        //给发送者添加 rnt代币
        rnt.mint(liquidityUser1, 1000000000000000000);
        assertEq(rnt.balanceOf(liquidityUser1), 1000000000000000000);

        vm.stopPrank();
    }

    //测试流动性添加
    function testAddLiquidity() public {
        vm.startPrank(liquidityUser1);
        //rnt 授权给 myDex 18个0
        rnt.approve(address(myDex), 1000000000000000000);

        //测试添加流动性
        // uint256 amountRNT = 1000;
        // uint256 amountETH = 1 ether;
        // uint256 amountRNTMin = 0;
        // uint256 amountETHMin = 0;
        // uint256 deadline = block.timestamp + 1000;
        // (uint256 amountToken, uint256 amountETHs, uint256 liquidity) = myDex.addLiquidity{ value: amountETH }(amountRNT, amountETHMin, amountRNTMin, deadline);
        // //断言
        // assertEq(amountToken, amountRNT);
        // assertEq(amountETH, amountETHs);
        // assert(liquidity > 0);
        vm.stopPrank();
    }
}
