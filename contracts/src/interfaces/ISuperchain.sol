// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IL2ToL2CrossDomainMessenger
/// @notice Interface for the Superchain low-latency messenger
interface IL2ToL2CrossDomainMessenger {
    function sendMessage(
        uint256 _destinationChainId,
        address _target,
        bytes calldata _message
    ) external returns (bytes32);
    
    function crossDomainMessageSender() external view returns (address);
    function crossDomainMessageSource() external view returns (uint256);
}

/// @title ISuperchainTokenBridge
/// @notice Interface for moving tokens across the Superchain
interface ISuperchainTokenBridge {
    function sendERC20(
        address _token,
        address _to,
        uint256 _amount,
        uint256 _chainId
    ) external returns (bytes32);
}