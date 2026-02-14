// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/ISuperchain.sol";
import "./interfaces/IOrbit.sol";

contract OrbitRouter is IOrbit {
    using SafeERC20 for IERC20;

    // --- Constants ---
    // Official Address of L2ToL2CrossDomainMessenger on OP Stack
    address public constant L2_MESSENGER = 0x4200000000000000000000000000000000000023;
    // Official Address of SuperchainTokenBridge (Standard)
    address public constant SUPERCHAIN_BRIDGE = 0x4200000000000000000000000000000000000010;

    // --- State ---
    // Mapping of ChainID -> Address of OrbitExecutor on that chain
    mapping(uint256 => address) public remoteExecutors;
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    /// @notice Admin function to trust a contract on another chain
    function setRemoteExecutor(uint256 _chainId, address _executor) external {
        require(msg.sender == owner, "Only owner");
        remoteExecutors[_chainId] = _executor;
    }

    /// @notice The User calls this function
    /// @param _tokenIn Address of token on Source Chain
    /// @param _amountIn Amount to swap
    /// @param _destChainId Which chain to go to (e.g., 10 for Optimism)
    /// @param _tokenOutOnDest Address of token user wants on Dest Chain
    /// @param _minAmountOut Slippage protection
    function initiateCrossChainSwap(
        address _tokenIn,
        uint256 _amountIn,
        uint256 _destChainId,
        address _tokenOutOnDest,
        uint24  _fee,           // <--- NEW PARAMETER
        uint256 _minAmountOut
    ) external {
        address destExecutor = remoteExecutors[_destChainId];
        require(destExecutor != address(0), "Destination chain not supported");

        // 1. Pull tokens from user
        IERC20(_tokenIn).safeTransferFrom(msg.sender, address(this), _amountIn);

        // 2. Bridge Tokens (Send to Destination Executor)
        IERC20(_tokenIn).forceApprove(SUPERCHAIN_BRIDGE, _amountIn);
        
        ISuperchainTokenBridge(SUPERCHAIN_BRIDGE).sendERC20(
            _tokenIn,
            destExecutor,
            _amountIn,
            _destChainId
        );

        // 3. Send Instructions (Message)
        SwapMessage memory payload = SwapMessage({
            user: msg.sender,
            tokenIn: _tokenIn, 
            tokenOut: _tokenOutOnDest,
            fee: _fee,           // <--- ADDED HERE
            amountIn: _amountIn,
            minAmountOut: _minAmountOut,
            deadline: block.timestamp + 30 minutes
        });

        bytes memory message = abi.encodeWithSelector(
            // Updated signature to include uint24
            bytes4(keccak256("executeSwap((address,address,address,uint24,uint256,uint256,uint256))")),
            payload
        );

        IL2ToL2CrossDomainMessenger(L2_MESSENGER).sendMessage(
            _destChainId,
            destExecutor,
            message
        );

        emit CrossChainSwapInitiated(msg.sender, _destChainId, _tokenIn, _amountIn);
    }
}