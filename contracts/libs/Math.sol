// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Math
 * @notice A library providing basic mathematical functions for Solidity contracts.
 * @dev Provides functions for calculating the minimum, maximum, and floor of two numbers. 
 * Includes error handling for division by zero.
*/

library Math {
    error ZeroDivision();

    /**
     * @notice Returns the smaller of two numbers.
     * @param a The first number.
     * @param b The second number.
     * @return uint256 The smaller of the two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @notice Returns the larger of two numbers.
     * @param a The first number.
     * @param b The second number.
     * @return uint256 The larger of the two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @notice Returns the floor of the division of two numbers.
     * @param numerator The numerator.
     * @param denominator The denominator.
     * @return uint256 The result of the division.
     * @dev Reverts with ZeroDivision if the denominator is zero.
     */
    function floor(uint256 numerator, uint256 denominator) internal pure returns (uint256) {
        if (denominator == 0) revert ZeroDivision();
        uint256 result = numerator / denominator; 
        return result;
    }
}
