// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/ISuperchain.sol";
import "./interfaces/IOrbit.sol";
import "./interfaces/ISwapRouter.sol";

contract OrbitExecutor is IOrbit {
    using SafeERC20 for IERC20;

    address public constant L2_MESSENGER = 0x4200000000000000000000000000000000000023;
    // Official Uniswap V3 SwapRouter Address (Same on Optimism, Base, etc.)
    address public constant UNISWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    
    address public owner;
    mapping(uint256 => address) public allowedRouters;

    constructor() {
        owner = msg.sender;
    }

    function setAllowedRouter(uint256 _chainId, address _router) external {
        require(msg.sender == owner, "Only owner");
        allowedRouters[_chainId] = _router;
    }

    function executeSwap(SwapMessage calldata _payload) external {
        // 1. Security Check
        require(msg.sender == L2_MESSENGER, "Caller must be L2 Messenger");
        uint256 sourceChain = IL2ToL2CrossDomainMessenger(L2_MESSENGER).crossDomainMessageSource();
        address sourceSender = IL2ToL2CrossDomainMessenger(L2_MESSENGER).crossDomainMessageSender();
        require(allowedRouters[sourceChain] == sourceSender, "Untrusted source router");

        // 2. Check Funds
        uint256 balance = IERC20(_payload.tokenIn).balanceOf(address(this));
        require(balance >= _payload.amountIn, "Insufficient bridged funds");

        // 3. Attempt Swap
        // We approve Uniswap to spend our tokens
        IERC20(_payload.tokenIn).forceApprove(UNISWAP_ROUTER, _payload.amountIn);

        try ISwapRouter(UNISWAP_ROUTER).exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: _payload.tokenIn,
                tokenOut: _payload.tokenOut,
                fee: _payload.fee,
                recipient: _payload.user, // Send result directly to user
                deadline: _payload.deadline,
                amountIn: _payload.amountIn,
                amountOutMinimum: _payload.minAmountOut,
                sqrtPriceLimitX96: 0
            })
        ) returns (uint256 amountOut) {
            // Happy Path: Swap succeeded
            emit SwapExecuted(_payload.user, _payload.tokenOut, amountOut);
        } catch (bytes memory reason) {
            // Sad Path: Swap failed (probably slippage)
            // Safety fallback: Send the ORIGINAL tokens to the user
            IERC20(_payload.tokenIn).safeTransfer(_payload.user, _payload.amountIn);
            emit SwapFailed(_payload.user, reason);
        }
    }
}