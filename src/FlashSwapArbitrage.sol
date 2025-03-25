// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./uniswap/interfaces/IUniswapV2Pair.sol";
import "./uniswap/interfaces/IUniswapV2Router.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FlashSwapArbitrage is Ownable {
    address public immutable factory;
    address public immutable router;

    address public poolA;
    address public poolB;

    event ArbitrageExecuted(uint256 amountIn, uint256 amountOut, uint256 profit);

    constructor(address _factory, address _router) Ownable(msg.sender) {
        factory = _factory;
        router = _router;
    }

    function setPools(address _poolA, address _poolB) external onlyOwner {
        poolA = _poolA;
        poolB = _poolB;
    }

    // 开始套利 tokenBorrow 是要借入的代币 amountBorrow 是要借入的数量 minProfit 是最小利润
    function startArbitrage(address tokenBorrow, uint256 amountBorrow, uint256 minProfit) external onlyOwner {
        require(poolA != address(0) && poolB != address(0), "Pools not set");
        require(amountBorrow > 0, "Amount must be greater than 0");
        require(tokenBorrow != address(0), "Invalid token address");

        IUniswapV2Pair pairA = IUniswapV2Pair(poolA);
        require(tokenBorrow == pairA.token0() || tokenBorrow == pairA.token1(), "Invalid token for poolA");

        //swap 的时候对回调函数进行签名
        bytes memory data = abi.encode(tokenBorrow, amountBorrow, minProfit);

        //这里只要 data 不为空就要出发 闪电贷 根据 排序计算借出的数量和偿还的数量 然后调用 uniswapV2Call 函数 
        pairA.swap(
            tokenBorrow == pairA.token0() ? amountBorrow : 0,
            tokenBorrow == pairA.token1() ? amountBorrow : 0,
            address(this),
            data
        );
    }

    // 回调函数 这个函数会在swap 之后被调用 sender 是调用者 amount0 是借出的数量 amount1 借出btoken 的数量比 data 是函数签名
    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        require(msg.sender == poolA, "Invalid caller");
        require(sender == address(this), "Invalid sender");
        //解析函数签名
        (address tokenBorrow, uint256 amountBorrow,) = abi.decode(data, (address, uint256, uint256));

        // 计算需要偿还的数量
        uint256 amountRequired = getAmountToRepay(amountBorrow, tokenBorrow);
        // 直接偿还PoolA
        require(IERC20(tokenBorrow).transfer(poolA, amountRequired), "Repay transfer failed");
    }

    function getAmountToRepay(uint256 amountBorrow, address tokenBorrow) internal view returns (uint256) {
        IUniswapV2Pair pair = IUniswapV2Pair(poolA);
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();

        uint256 reserveIn = tokenBorrow == pair.token0() ? reserve0 : reserve1;
        uint256 reserveOut = tokenBorrow == pair.token0() ? reserve1 : reserve0;

        uint256 amountInWithFee = amountBorrow * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;

        require(denominator > 0, "Division by zero");
        return numerator / denominator;
    }

    function withdrawToken(address token, uint256 amount) external onlyOwner {
        require(token != address(0), "Invalid token address");
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance >= amount, "Insufficient balance");
        require(IERC20(token).transfer(owner(), amount), "Withdraw failed");
    }
}
