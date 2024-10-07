// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./Chip.sol";

library jajca {
    function asReturnsUint256AndUint96(
        function(address) internal view returns (uint256) fnIn
    ) internal pure returns (function(address) internal view returns (uint256, uint96) fnOut) {
        assembly {
            fnOut := fnIn
        }
    }
}