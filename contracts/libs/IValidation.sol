// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IValidation
 * @notice A library for validating ERC20 token contracts.
 * @dev Provides a function to validate if a given address is an ERC20 token 
 * by checking for the presence of the `decimals()` function.
*/

library IValidation {
    /**
     * @notice Validates if the given address is an ERC20 token contract.
     * @dev This function checks if the address implements the `decimals()` function.
     * @param tokenAddress The address to validate.
     * @return bool True if the address is an ERC20 token contract, false otherwise.
     */
    function validateERC20Token(address tokenAddress) internal view returns (bool) {
        bytes4 decimalsSig = bytes4(keccak256("decimals()"));

        (bool success, bytes memory data) = tokenAddress.staticcall(abi.encodeWithSelector(decimalsSig));

        return success && data.length == 32;
    }
}
