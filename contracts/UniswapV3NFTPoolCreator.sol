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

    address OWNER_WALLET = 0x35bD3F9cF97ffb44681805166fE9F7B793c543b8;



    
    int24 private constant MIN_TICK = -887272;
    int24 private constant MAX_TICK = -MIN_TICK;
    int24 private constant TICK_SPACING = 60;


    IUniswapV3Factory private v3Factory;
    INonfungiblePositionManager private nftPositionManager;
    ISwapRouter private swapRouter;


    IERC20 public tokenBuy;
    uint256 public deploymentCost = 20 * 10**18; // Assuming 18 decimal places in the token


    constructor(IERC20 _token , address[] memory _owners, uint256 _numConfirmationsRequired) MultiSig (_owners, _numConfirmationsRequired) {
        tokenBuy = _token;

        // require(tokenBuy.balanceOf(msg.sender) >= deploymentCost, "Not enough tokens to deploy");
        // require(tokenBuy.allowance(msg.sender, address(this)) >= deploymentCost, "Token allowance too low");
        // require(tokenBuy.transferFrom(msg.sender, OWNER_WALLET, deploymentCost), "Token transfer failed");

        v3Factory = IUniswapV3Factory(UNISWAP_V3_FACTORY);
        nftPositionManager = INonfungiblePositionManager(UNISWAP_V3_NFT_POSITION_MANAGER);
        swapRouter = ISwapRouter(UNISWAP_V3_ROUTER);

    }
    receive() external payable {}


    function transferTokens() external {
        require(tokenBuy.balanceOf(msg.sender) >= deploymentCost, "Insufficient token balance");
        require(tokenBuy.allowance(msg.sender, address(this)) >= deploymentCost, "Token allowance too low");
        bool success = tokenBuy.transferFrom(msg.sender, OWNER_WALLET, deploymentCost);
        require(success, "Token transfer failed");
    }

    // This method is used to execute a specific function based on the transaction ID provided. It decodes the transaction's data
    // and calls the appropriate internal function.
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
            (address token0,address token1,uint24 fee,uint256 amount0ToAdd,uint256 amount1ToAdd,uint256 initialPrice,uint160 minPrice,uint160 maxPrice , uint256 etherAmount) = abi.decode(transactionMap[_transactionId].data, (address ,address ,uint24 ,uint256 ,uint256 ,uint256 ,uint160 ,uint160 , uint256 ));
            outputData  = _createPoolAndMintNFT( token0, token1, fee, amount0ToAdd, amount1ToAdd, initialPrice, minPrice, maxPrice , etherAmount );
        }else if ((keccak256(abi.encodePacked(transactionMap[_transactionId].functionName)) == keccak256(abi.encodePacked(("_collectAllFees"))))) {
            (uint tokenId) = abi.decode(transactionMap[_transactionId].data, (uint));
            outputData  = _collectAllFees(tokenId);
        }else if ((keccak256(abi.encodePacked(transactionMap[_transactionId].functionName)) == keccak256(abi.encodePacked(("_increaseLiquidityCurrentRange"))))) {
            (address token0,address token1,uint tokenId,uint amount0ToAdd,uint amount1ToAdd) = abi.decode(transactionMap[_transactionId].data, (address , address , uint , uint ,uint));
            outputData  = _increaseLiquidityCurrentRange(token0, token1, tokenId, amount0ToAdd, amount1ToAdd);
        }else if ((keccak256(abi.encodePacked(transactionMap[_transactionId].functionName)) == keccak256(abi.encodePacked(("_decreaseLiquidityCurrentRange"))))) {
            (uint tokenId,uint128 liquidity) = abi.decode(transactionMap[_transactionId].data, (uint ,uint128 ));
            outputData  = _decreaseLiquidityCurrentRange( tokenId, liquidity);
        }else if ((keccak256(abi.encodePacked(transactionMap[_transactionId].functionName)) == keccak256(abi.encodePacked(("_removePool"))))) {
            (uint tokenId, uint128 liquidity) = abi.decode(transactionMap[_transactionId].data, (uint ,uint128 ));
            outputData  = _removePool(  tokenId,  liquidity);
        }else if ((keccak256(abi.encodePacked(transactionMap[_transactionId].functionName)) == keccak256(abi.encodePacked(("_transferERC20"))))) {
            (address tokenContractAddress,address recipient,uint256 amount) = abi.decode(transactionMap[_transactionId].data, (address ,address ,uint256  ));
            _transferERC20( tokenContractAddress, recipient, amount);
        }else if ((keccak256(abi.encodePacked(transactionMap[_transactionId].functionName)) == keccak256(abi.encodePacked(("_sendEther"))))) {
            (address payable recipient, uint256 amount) = abi.decode(transactionMap[_transactionId].data, (address  , uint256   ));
            _sendEther( recipient, amount);
        }
    }

    //Swap Funcs :-

    //************************** Start Swap **********************************


    function swap(address _tokenIn,address _tokenOut,uint256 _amountIn,uint256 _amountOutMin,uint24 _fee) external onlyOwner returns (uint256 _transactionId) {
        return submitTransaction(msg.sender, "_swap" , abi.encode(_tokenIn,_tokenOut,_amountIn,_amountOutMin,_fee));
    }

    // This method is an internal function used for swapping tokens on the Uniswap V3 exchange. It takes two tokens (input and output),
    // the input token amount, the minimum output token amount, and the fee tier as parameters.
    function _swap(address _tokenIn,address _tokenOut,uint256 _amountIn,uint256 _amountOutMin,uint24 _fee) internal {
        // Approve the Uniswap V3 router to spend the input token on behalf of the contract.
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

    //************************** START POOL **********************************


    function createPoolAndMintNFT(address token0,address token1,uint24 fee,uint256 amount0ToAdd,uint256 amount1ToAdd,uint256 initialPrice,uint160 minPrice,uint160 maxPrice)external payable onlyOwner returns (uint256 _transactionId) {
        return submitTransaction(msg.sender, "_createPoolAndMintNFT" , abi.encode(token0,token1,fee,amount0ToAdd,amount1ToAdd,initialPrice,minPrice,maxPrice , msg.value)) ;

    }

    // This method is an internal function used to create a new liquidity pool on Uniswap V3, add liquidity to it, and mint a
    // corresponding NFT position. It takes the following parameters: token0, token1, fee tier, amounts of token0 and token1 to add,
    // initial price, price range (minPrice and maxPrice), and ether amount for pool creation.
    function _createPoolAndMintNFT(address token0,
        address token1,
        uint24 fee,
        uint256 amount0ToAdd,
        uint256 amount1ToAdd,
        uint256 initialPrice,
        uint160 minPrice,
        uint160 maxPrice,
        uint256 etherAmount
        ) internal returns (bytes memory) {

        //address pool = this.createAndInitializePool{value: etherAmount}(token0, token1, fee, initialPrice);
        // Calculate the square root price for the pool using the initial price provided.
        uint160 sqrtPriceX96 = UniswapV3PriceCalculator.calculateSqrtPriceX96(initialPrice);
        // Create and initialize the pool if necessary, using the provided ether amount.
        address pool = nftPositionManager.createAndInitializePoolIfNecessary{value: etherAmount}(
            token0,
            token1,
            fee,
            sqrtPriceX96
        );

        IERC20 tokenA = IERC20(token0);
        IWETH  tokenB = IWETH(token1);

        tokenA.transferFrom(msg.sender, address(this), amount0ToAdd);
        tokenB.transferFrom(msg.sender, address(this), amount1ToAdd);

        tokenA.approve(address(nftPositionManager), amount0ToAdd);
        tokenB.approve(address(nftPositionManager), amount1ToAdd);

        // Calculate the tick range based on the provided price range.
        (int24 _tickLower, int24 _tickUpper) = UniswapV3PriceCalculator.calculateTicksFromPriceRange(minPrice , maxPrice);

        // Set up the parameters for minting the NFT position.
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

        // Mint the NFT position and add liquidity to the pool.
        (uint tokenId, uint128 liquidity, uint amount0, uint amount1) = nftPositionManager.mint(mintParams);

        // Refund any unused tokens back to the sender.
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

    /////////////////////////////////////////////////////
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
    /////////////////////////////////////////////////////

    function collectAllFees(
        uint tokenId
    ) external onlyOwner returns (uint256 _transactionId) {
        return submitTransaction(msg.sender, "_collectAllFees" , abi.encode(tokenId)) ;

    }
    //(uint amount0, uint amount1)
    function _collectAllFees(
        uint tokenId
    ) internal returns (bytes memory) {
        INonfungiblePositionManager.CollectParams
            memory params = INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            });

        (uint amount0, uint amount1) = nftPositionManager.collect(params);

        bytes memory outputData = abi.encode(amount0, amount1);

        return outputData;


    }



    function increaseLiquidityCurrentRange(
        address token0,
        address token1,
        uint tokenId,
        uint amount0ToAdd,
        uint amount1ToAdd
    ) external onlyOwner returns (uint256 _transactionId)  {
        return submitTransaction(msg.sender, "_increaseLiquidityCurrentRange" , abi.encode(token0,token1,tokenId,amount0ToAdd,amount1ToAdd)) ;
    }

    //(uint128 liquidity, uint amount0, uint amount1)
    function _increaseLiquidityCurrentRange(
        address token0,
        address token1,
        uint tokenId,
        uint amount0ToAdd,
        uint amount1ToAdd
    ) internal returns (bytes memory)  {

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

        (uint128 liquidity, uint amount0,uint amount1) = nftPositionManager.increaseLiquidity(params);

        bytes memory outputData = abi.encode(liquidity, amount0, amount1);

        return outputData;
    }

    function decreaseLiquidityCurrentRange(uint tokenId,uint128 liquidity) external onlyOwner returns (uint256 _transactionId)  {
        return submitTransaction(msg.sender, "_decreaseLiquidityCurrentRange" , abi.encode(tokenId,liquidity)) ;

    }

    //returns (uint amount0, uint amount1)
    function _decreaseLiquidityCurrentRange(uint tokenId,uint128 liquidity) internal returns (bytes memory)  {
        INonfungiblePositionManager.DecreaseLiquidityParams
            memory params = INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: liquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            });

        (uint amount0, uint amount1) = nftPositionManager.decreaseLiquidity(params);

        bytes memory outputData = abi.encode(amount0, amount1);

        return outputData;
    }

    function removePool(uint tokenId, uint128 liquidity) external onlyOwner returns (uint256 _transactionId)  {
        return submitTransaction(msg.sender, "_removePool" , abi.encode(tokenId,liquidity)) ;
    }

    // This internal function is used to remove liquidity from a Uniswap V3 pool and collect any accrued fees.
    // It takes two parameters: tokenId, which represents the NFT position, and liquidity, the amount of liquidity to remove.
    function _removePool(uint tokenId, uint128 liquidity) internal returns (bytes memory){
        
        // Set up the parameters to decrease liquidity for the NFT position.
        INonfungiblePositionManager.DecreaseLiquidityParams
            memory decreaseLiquidityParams = INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: liquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            });

        (uint amount0, uint amount1) = nftPositionManager.decreaseLiquidity(decreaseLiquidityParams);

        // Set up the parameters to collect the accrued fees for the NFT position.
        INonfungiblePositionManager.CollectParams
            memory collectParams = INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            });
        
        // Collect the accrued fees for the NFT position and get the amounts of token0 and token1 fees collected.
        (uint fees0, uint fees1) = nftPositionManager.collect(collectParams);

        bytes memory outputData = abi.encode(amount0, amount1, fees0, fees1);

        return outputData;
    }

    //************************** END POOL **********************************



    //************************** START COIN **********************************


    function transferERC20(address tokenContractAddress,address recipient,uint256 amount) external onlyOwner returns (uint256 _transactionId) {
        return submitTransaction(msg.sender, "_transferERC20" , abi.encode(tokenContractAddress,recipient ,amount)) ;

    }

    function _transferERC20(address tokenContractAddress,address recipient,uint256 amount) internal {
        IERC20 token = IERC20(tokenContractAddress);
        require(token.balanceOf(address(this)) >= amount, "Insufficient balance");

        // In a real-world scenario, you would need to implement private key handling and signing.
        // This example assumes the sender has granted approval to the contract for transferring tokens.
        token.transfer(recipient, amount);
    }

    function sendEther(address payable recipient, uint256 amount) external onlyOwner returns (uint256 _transactionId) {
        return submitTransaction(msg.sender, "_sendEther" , abi.encode(recipient ,amount)) ;

    }

    // Function to send Ether from the contract to a recipient
    function _sendEther(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Insufficient balance in the contract");

        // Transfer Ether to the recipient
        recipient.transfer(amount);
    }


    //************************** END COIN **********************************




}
