// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {CreateXScript} from "./CreateXScript.sol";

// Example contract
import {EmojiProtocol} from "../src/EmojiProtocol.sol";

contract Deploy is Script, CreateXScript {

    function run() public {
        vm.startBroadcast();

        address deployer = msg.sender;
        bytes32 salt = bytes32(0x644c1564d1d19cf336417734170f21b94410907400645f724608bb4f0006204d);

        // Calculate the predetermined address of the Counter contract deployment
        address computedAddress = computeCreate3Address(salt, deployer);

        // Replace these with actual addresses
        
        address _entropy = 0x6E7D74FA7d5c90FEF9F0512987605a6d546181Bb;
        address _entropyProvider = 0x52DeaA1c84233F7bb8C8A45baeDE41091c616506;


        //uint256 arg1 = 42;
        address deployedAddress = create3(salt, abi.encodePacked(type(EmojiProtocol).creationCode, abi.encode(_entropy, _entropyProvider)));

        // Check to make sure contract is on the expected address
        require(computedAddress == deployedAddress, "Computed and deployed address do not match!");

        EmojiProtocol emojiProtocol = EmojiProtocol(payable(deployedAddress));

        // // base
        // emojiProtocol.initialize(
        //     0x2626664c2603336E57B271c5C0b26F421741e481,
        //     0x2Da56AcB9Ea78330f947bD57C54119Debda7AF71,
        //     0x4200000000000000000000000000000000000006
        //
        // );
        
        // // eth
        // emojiProtocol.initialize(
        //     0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45,
        //     0xaaeE1A9723aaDB7afA2810263653A34bA2C21C7a,
        //     0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
        // );

        vm.stopBroadcast();
    }
}



        