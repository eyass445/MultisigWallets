// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "https://github.com/Uniswap/v3-periphery/blob/0.8/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IMulticall.sol";
import "https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/TransferHelper.sol";
import "@uniswap/v3-core/contracts/libraries/FixedPoint96.sol";
import "./lib/UniswapV3PriceCalculator.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IUniswapV3PoolCreator.sol";
import "./MultiSig.sol";
import "./interfaces/IMultiSig.sol";


// IERC721Receiver ,
contract UniswapV3NFTPoolCreator is  MultiSig  {
    // Uniswap V3 Factory address
    address public constant UNISWAP_V3_FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

    // Uniswap V3 NFT Position Manager address
    address public constant UNISWAP_V3_NFT_POSITION_MANAGER = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;

    address private constant UNISWAP_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;


    
    int24 private constant MIN_TICK = -887272;
    int24 private constant MAX_TICK = -MIN_TICK;
    int24 private constant TICK_SPACING = 60;


    IUniswapV3Factory private v3Factory;
    INonfungiblePositionManager private nftPositionManager;
    ISwapRouter private swapRouter;


    constructor(address[] memory _owners, uint256 _numConfirmationsRequired) MultiSig (_owners, _numConfirmationsRequired) {
        v3Factory = IUniswapV3Factory(UNISWAP_V3_FACTORY);
        nftPositionManager = INonfungiblePositionManager(UNISWAP_V3_NFT_POSITION_MANAGER);
        swapRouter = ISwapRouter(UNISWAP_V3_ROUTER);

    }
    receive() external payable {}

    function executeFunction (uint256 _transactionId) internal override returns (bytes memory  outputData)  {

        if ((keccak256(abi.encodePacked(transactionMap[_transactionId].functionName)) == keccak256(abi.encodePacked(("_swap"))))) {
            (address _tokenIn,address _tokenOut,uint256 _amountIn,uint256 _amountOutMin,uint24 _fee) = abi.decode(transactionMap[_transactionId].data,( address ,address ,uint256 ,uint256 ,uint24));
            _swap( _tokenIn, _tokenOut, _amountIn, _amountOutMin, _fee);
        } else if ((keccak256(abi.encodePacked(transactionMap[_transactionId].functionName)) == keccak256(abi.encodePacked(("_unwrapWETH"))))) {
            (address wtoken ,uint256 amount) = abi.decode(transactionMap[_transactionId].data, (address ,uint256 ));
            _unwrapWETH( wtoken , amount);
        } else if ((keccak256(abi.encodePacked(transactionMap[_transactionId].functionName)) == keccak256(abi.encodePacked(("_wrapETH"))))) {
            (address wtoken ,uint256 amount) = abi.decode(transactionMap[_transactionId].data, (address ,uint256 ));
            _wrapETH(wtoken , amount);
        } else if ((keccak256(abi.encodePacked(transactionMap[_transactionId].functionName)) == keccak256(abi.encodePacked(("_createPoolAndMintNFT"))))) {
            (address token0,address token1,uint24 fee,uint256 amount0ToAdd,uint256 amount1ToAdd,uint256 initialPrice,uint160 minPrice,uint160 maxPrice) = abi.decode(transactionMap[_transactionId].data, (address ,address ,uint24 ,uint256 ,uint256 ,uint256 ,uint160 ,uint160 ));
            outputData  = _createPoolAndMintNFT( token0, token1, fee, amount0ToAdd, amount1ToAdd, initialPrice, minPrice, maxPrice);
            // (address pool, int24 _tickLower, int24 _tickUpper, uint tokenId, uint128 liquidity, uint amount0, uint amount1) = abi.decode(outputData, (address, int24, int24, uint, uint128, uint, uint));

        }
    }

    //Swap Funcs :-

    //************************** Start Swap **********************************


    function swap(address _tokenIn,address _tokenOut,uint256 _amountIn,uint256 _amountOutMin,uint24 _fee) external onlyOwner returns (uint256 _transactionId) {
        return submitTransaction(msg.sender, "_swap" , abi.encode(_tokenIn,_tokenOut,_amountIn,_amountOutMin,_fee));
    }


    function _swap(address _tokenIn,address _tokenOut,uint256 _amountIn,uint256 _amountOutMin,uint24 _fee) internal {
        //require(IERC20(_tokenIn).transferFrom(msg.sender, address(this), _amountIn), "Transfer failed");
        require(IERC20(_tokenIn).approve(UNISWAP_V3_ROUTER, _amountIn), "Approval failed");
 

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: _tokenIn,
            tokenOut: _tokenOut,
            fee: _fee, // Choose an appropriate fee tier (e.g., 500, 3000, or 10000)
            recipient: address(this),
            deadline: block.timestamp + 3600, // Set an appropriate deadline
            amountIn: _amountIn,
            amountOutMinimum: _amountOutMin,
            sqrtPriceLimitX96: 0 // No price limit
        });

        swapRouter.exactInputSingle(params);
    }



    function unwrapWETH(address wtoken ,uint256 amount) external onlyOwner returns (uint256 _transactionId) {
        return submitTransaction(msg.sender, "_unwrapWETH" , abi.encode(wtoken, amount));
    }


     // Unwraps WETH to ETH
    function _unwrapWETH(address wtoken ,uint256 amount) internal {
        require(amount > 0, "Amount must be greater than 0");

        // Unwrap WETH to ETH
        IWETH(wtoken).withdraw(amount);

        // Transfer unwrapped ETH back to the user
        (bool success, ) = address(this).call{value: amount}("");
        require(success, "Failed to transfer Ether");
    }


    
    // Function to wrap a specific amount of ETH held by the contract to WETH
    function wrapETH(address wtoken, uint256 amount) external onlyOwner returns (uint256 _transactionId) {
        return submitTransaction(msg.sender, "_wrapETH" , abi.encode(wtoken, amount));

    }

    function _wrapETH(address wtoken, uint256 amount) internal {
        uint256 contractEthBalance = address(this).balance;
        require(contractEthBalance >= amount, "Insufficient ETH balance in the contract");
        require(amount > 0, "Amount must be greater than 0");

        // Wrap the specified amount of ETH held by the contract to WETH
        IWETH(wtoken).deposit{value: amount}();
    }

    //************************** END Swap **********************************



    // function transferAndApprove(
    //     IERC20 tokenA,
    //     IWETH tokenB,
    //     uint amount0ToAdd,
    //     uint amount1ToAdd
    // ) external  {
    //     //IERC20 tokenA = IERC20(_tokenA);
    //     //IWETH  tokenB = IWETH(_tokenB);

    //     tokenA.transferFrom(msg.sender, address(this), amount0ToAdd);
    //     tokenB.transferFrom(msg.sender, address(this), amount1ToAdd);

    //     tokenA.approve(address(nftPositionManager), amount0ToAdd);
    //     tokenB.approve(address(nftPositionManager), amount1ToAdd);
    // }

    function createPoolAndMintNFT(address token0,address token1,uint24 fee,uint256 amount0ToAdd,uint256 amount1ToAdd,uint256 initialPrice,uint160 minPrice,uint160 maxPrice)external payable onlyOwner returns (uint256 _transactionId) {
        return submitTransaction(msg.sender, "_createPoolAndMintNFT" , abi.encode(token0,token1,fee,amount0ToAdd,amount1ToAdd,initialPrice,minPrice,maxPrice)) ;

    }
   
    function _createPoolAndMintNFT(address token0,
        address token1,
        uint24 fee,
        uint256 amount0ToAdd,
        uint256 amount1ToAdd,
        uint256 initialPrice,
        uint160 minPrice,
        uint160 maxPrice
        ) internal returns (bytes memory) {

        address pool = this.createAndInitializePool{value: msg.value}(token0, token1, fee, initialPrice);

        IERC20 tokenA = IERC20(token0);
        IWETH  tokenB = IWETH(token1);

        tokenA.transferFrom(msg.sender, address(this), amount0ToAdd);
        tokenB.transferFrom(msg.sender, address(this), amount1ToAdd);

        tokenA.approve(address(nftPositionManager), amount0ToAdd);
        tokenB.approve(address(nftPositionManager), amount1ToAdd);

        (int24 _tickLower, int24 _tickUpper) = UniswapV3PriceCalculator.calculateTicksFromPriceRange(minPrice , maxPrice);

        INonfungiblePositionManager.MintParams memory mintParams = INonfungiblePositionManager.MintParams({
            token0: token0,
            token1: token1,
            fee: fee,
            tickLower: _tickLower,
            tickUpper: _tickUpper,
            amount0Desired: amount0ToAdd,
            amount1Desired: amount1ToAdd,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(this),
            deadline: block.timestamp
        });

        (uint tokenId, uint128 liquidity, uint amount0, uint amount1) = nftPositionManager.mint(mintParams);

        if (amount0 < amount0ToAdd) {
            tokenA.approve(address(nftPositionManager), 0);
            uint refund0 = amount0ToAdd - amount0;
            tokenA.transfer(msg.sender, refund0);
        }
        if (amount1 < amount1ToAdd) {
            tokenB.approve(address(nftPositionManager), 0);
            uint refund1 = amount1ToAdd - amount1;
            tokenB.transfer(msg.sender, refund1);
        }

        // Encode the return values as a bytes value
        bytes memory outputData = abi.encode(pool, _tickLower, _tickUpper, tokenId, liquidity, amount0, amount1);

        return outputData;
    }

    // function _createPoolAndMintNFT(address token0,
    //     address token1,
    //     uint24 fee,
    //     uint256 amount0ToAdd,
    //     uint256 amount1ToAdd,
    //     //address recipient,
    //     uint256 initialPrice,
    //     uint160 minPrice,
    //     uint160 maxPrice
    //     ) internal returns (address pool ,int24 _tickLower ,int24 _tickUpper , uint tokenId, uint128 liquidity, uint amount0, uint amount1) {

    //     pool = this.createAndInitializePool{value: 0}(token0, token1, fee, initialPrice);

    //     IERC20 tokenA = IERC20(token0);
    //     IWETH  tokenB = IWETH(token1);


    //     tokenA.transferFrom(msg.sender, address(this), amount0ToAdd);
    //     tokenB.transferFrom(msg.sender, address(this), amount1ToAdd);

    //     tokenA.approve(address(nftPositionManager), amount0ToAdd);
    //     tokenB.approve(address(nftPositionManager), amount1ToAdd);


    //     ( _tickLower , _tickUpper ) = UniswapV3PriceCalculator.calculateTicksFromPriceRange(minPrice , maxPrice);


    //     INonfungiblePositionManager.MintParams memory mintParams = INonfungiblePositionManager.MintParams({
    //         token0: token0,
    //         token1: token1,
    //         fee: fee,
    //         tickLower: _tickLower,
    //         tickUpper: _tickUpper,
    //         amount0Desired: amount0ToAdd,
    //         amount1Desired: amount1ToAdd,
    //         amount0Min: 0,
    //         amount1Min: 0,
    //         recipient: address(this),
    //         deadline: block.timestamp
    //     });


    //     (tokenId, liquidity, amount0, amount1) = nftPositionManager.mint(
    //         mintParams
    //     );

    //     if (amount0 < amount0ToAdd) {
    //         tokenA.approve(address(nftPositionManager), 0);
    //         uint refund0 = amount0ToAdd - amount0;
    //         tokenA.transfer(msg.sender, refund0);
    //     }
    //     if (amount1 < amount1ToAdd) {
    //         tokenB.approve(address(nftPositionManager), 0);
    //         uint refund1 = amount1ToAdd - amount1;
    //         tokenB.transfer(msg.sender, refund1);
    //     }
    // }




    
    function createAndInitializePool(
        address token0,
        address token1,
        uint24 fee,
        uint256 initialPrice
    ) external payable returns (address pool) {
        
        //uint160 x  = initialPrice * (2 << 96);
        uint160 sqrtPriceX96 = UniswapV3PriceCalculator.calculateSqrtPriceX96(initialPrice);
        address newPool = nftPositionManager.createAndInitializePoolIfNecessary{value: msg.value}(
            token0,
            token1,
            fee,
            sqrtPriceX96
        );

        return newPool;
        // Perform additional operations with the created or initialized pool if necessary
    }


    function collectAllFees(
        uint tokenId
    ) external returns (uint amount0, uint amount1) {
        INonfungiblePositionManager.CollectParams
            memory params = INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            });

        (amount0, amount1) = nftPositionManager.collect(params);
    }

    function increaseLiquidityCurrentRange(
        address token0,
        address token1,
        uint tokenId,
        uint amount0ToAdd,
        uint amount1ToAdd
    ) external returns (uint128 liquidity, uint amount0, uint amount1) {

        IERC20 tokenA = IERC20(token0);
        IWETH  tokenB = IWETH(token1);

        tokenA.transferFrom(msg.sender, address(this), amount0ToAdd);
        tokenB.transferFrom(msg.sender, address(this), amount1ToAdd);

        tokenA.approve(address(nftPositionManager), amount0ToAdd);
        tokenB.approve(address(nftPositionManager), amount1ToAdd);

        INonfungiblePositionManager.IncreaseLiquidityParams memory params = INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: tokenId,
                amount0Desired: amount0ToAdd,
                amount1Desired: amount1ToAdd,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            });

        (liquidity, amount0, amount1) = nftPositionManager.increaseLiquidity(
            params
        );
    }

    function decreaseLiquidityCurrentRange(
        uint tokenId,
        uint128 liquidity
    ) external returns (uint amount0, uint amount1) {
        INonfungiblePositionManager.DecreaseLiquidityParams
            memory params = INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: liquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            });

        (amount0, amount1) = nftPositionManager.decreaseLiquidity(params);
    }

    function removePool(uint tokenId, uint128 liquidity) external returns (uint amount0, uint amount1, uint fees0, uint fees1) {
        // Decrease liquidity
        INonfungiblePositionManager.DecreaseLiquidityParams
            memory decreaseLiquidityParams = INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: liquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            });

        (amount0, amount1) = nftPositionManager.decreaseLiquidity(decreaseLiquidityParams);

        // Collect fees
        INonfungiblePositionManager.CollectParams
            memory collectParams = INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            });

        (fees0, fees1) = nftPositionManager.collect(collectParams);
    }

    function transferERC20(
        address tokenContractAddress,
        address recipient,
        uint256 amount
    ) external {
        IERC20 token = IERC20(tokenContractAddress);
        require(token.balanceOf(address(this)) >= amount, "Insufficient balance");

        // In a real-world scenario, you would need to implement private key handling and signing.
        // This example assumes the sender has granted approval to the contract for transferring tokens.
        token.transfer(recipient, amount);
    }

    // Function to send Ether from the contract to a recipient
    function sendEther(address payable recipient, uint256 amount) external {
        require(address(this).balance >= amount, "Insufficient balance in the contract");

        // Transfer Ether to the recipient
        recipient.transfer(amount);
    }



}
