// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IWETH.sol";


interface IUniswapV3PoolCreator {
    // function onERC721Received(
    //     address operator,
    //     address from,
    //     uint tokenId,
    //     bytes calldata data
    // ) external returns (bytes4);

    // Function to perform a swap between two tokens

    function swap(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint256 _amountOutMin,
        uint24 _fee
    ) external;

    // Function to unwrap WETH to ETH
    function unwrapWETH(address wtoken, uint256 amount) external;

    // Function to wrap ETH to WETH
    function wrapETH(address wtoken, uint256 amount) external;

    // Function to transfer and approve tokens
    function transferAndApprove(
        IERC20 tokenA,
        IWETH tokenB,
        uint amount0ToAdd,
        uint amount1ToAdd
    ) external;

    // Function to create a pool, mint an NFT, and add liquidity
    function createPoolAndMintNFT(
        address token0,
        address token1,
        uint24 fee,
        uint256 amount0ToAdd,
        uint256 amount1ToAdd,
        uint256 initialPrice,
        uint160 minPrice,
        uint160 maxPrice
    ) external payable returns (address pool, int24 _tickLower, int24 _tickUpper, uint tokenId, uint128 liquidity, uint amount0, uint amount1);

    // Function to create and initialize a Uniswap V3 pool
    function createAndInitializePool(
        address token0,
        address token1,
        uint24 fee,
        uint256 initialPrice
    ) external payable returns (address pool);

    function collectAllFees(
        uint tokenId
    ) external returns (uint amount0, uint amount1);

    function increaseLiquidityCurrentRange(
        address token0,
        address token1,
        uint tokenId,
        uint amount0ToAdd,
        uint amount1ToAdd
    ) external returns (uint128 liquidity, uint amount0, uint amount1);

    function decreaseLiquidityCurrentRange(
        uint tokenId,
        uint128 liquidity
    ) external returns (uint amount0, uint amount1);

    function removePool(
        uint tokenId,
        uint128 liquidity
    ) external returns (uint amount0, uint amount1, uint fees0, uint fees1);

    function transferERC20(
        address tokenContractAddress,
        address recipient,
        uint256 amount
    ) external;

    function sendEther(address payable recipient, uint256 amount) external;
}
