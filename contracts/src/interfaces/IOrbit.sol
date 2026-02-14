// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IOrbit {
    /// @notice The instructions to execute on the destination chain
    struct SwapMessage {
        address user;           // The user who initiated the swap
        address tokenIn;        // The token received on dest chain (e.g., ETH)
        address tokenOut;       // The token the user wants (e.g., USDC)
        uint24  fee;            // Uniswap Pool Fee (e.g., 3000 for 0.3%)
        uint256 amountIn;       // Amount bridged
        uint256 minAmountOut;   // Slippage protection
        uint256 deadline;       // When to expire
    }

    /// @notice Event emitted on source chain
    event CrossChainSwapInitiated(
        address indexed user,
        uint256 destinationChainId,
        address tokenIn,
        uint256 amount
    );

    /// @notice Event emitted on destination chain
    event SwapExecuted(
        address indexed user,
        address tokenOut,
        uint256 amountOut
    );

    /// @notice Event emitted if swap fails and funds are returned
    event SwapFailed(
        address indexed user,
        bytes reason
    );
}