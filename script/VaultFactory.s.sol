// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/VaultFactory.sol";

contract FactoryDeployer is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        VaultFactory factory = new VaultFactory(3 days, 50 days, msg.sender);

        vm.stopBroadcast();
    }
}