// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/ISuperchain.sol";
import "./interfaces/IOrbit.sol";

contract OrbitExecutor is IOrbit {
    using SafeERC20 for IERC20;

    address public constant L2_MESSENGER = 0x4200000000000000000000000000000000000023;
    address public owner;
    
    // Whitelist of allowed Router contracts on other chains
    // ChainID -> RouterAddress
    mapping(uint256 => address) public allowedRouters;

    constructor() {
        owner = msg.sender;
    }

    function setAllowedRouter(uint256 _chainId, address _router) external {
        require(msg.sender == owner, "Only owner");
        allowedRouters[_chainId] = _router;
    }

    /// @notice Called by the L2CrossDomainMessenger
    function executeSwap(SwapMessage calldata _payload) external {
        // --- Security Checks ---
        // 1. Ensure caller is the L2 Messenger
        require(msg.sender == L2_MESSENGER, "Caller must be L2 Messenger");

        // 2. Ensure the message originated from a trusted OrbitRouter
        uint256 sourceChain = IL2ToL2CrossDomainMessenger(L2_MESSENGER).crossDomainMessageSource();
        address sourceSender = IL2ToL2CrossDomainMessenger(L2_MESSENGER).crossDomainMessageSender();
        
        require(allowedRouters[sourceChain] == sourceSender, "Untrusted source router");

        // --- Execution Logic ---
        
        // At this point, the `SuperchainTokenBridge` should have already minted/sent 
        // the tokens to this contract address. Let's verify we have them.
        uint256 balance = IERC20(_payload.tokenIn).balanceOf(address(this));
        
        // If bridge failed or is slow, we might have a problem. 
        // In production, we might need a "retry" mechanism here. 
        // For now, we require funds to be present.
        require(balance >= _payload.amountIn, "Bridge funds not arrived yet");

        // --- SWAP LOGIC (Placeholder for Step 3) ---
        // Right now, we will just simulate the swap by sending the input tokens 
        // directly to the user (mocking a 1:1 swap failure fallback).
        // In Step 3, we will insert the Uniswap V3 Router call here.
        
        IERC20(_payload.tokenIn).safeTransfer(_payload.user, _payload.amountIn);
        
        emit SwapExecuted(_payload.user, _payload.tokenIn, _payload.amountIn);
    }
}