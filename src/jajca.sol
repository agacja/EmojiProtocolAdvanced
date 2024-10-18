// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { TokenData } from './ChipStructs.sol';
library jajca {
    function asReturnsTokenData(
        function(uint256) internal view returns (uint256) fnIn
    ) internal pure returns (function(uint256) internal view returns (TokenData memory) fnOut) {
        assembly {
            fnOut := fnIn
        }
    }

    function asReturnsPointers(
        function(uint256) internal view returns (TokenData memory) fnIn
    ) internal pure returns (function(uint256) internal view returns (uint256) fnOut) {
        assembly {
            fnOut := fnIn
        }
    }
}