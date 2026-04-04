//SPDX-License-Identifier:MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {
    VRFCoordinatorV2_5Mock
} from "chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract DeployRaffle is Script {
    uint256 constant ANVIL_CHAIN_ID = 31337;

    function run() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getActiveNetworkConfig();

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            config.entranceFee, config.interval, config.keyHash, config.subscriptionId, config.vrfCoordinator
        );
        if (block.chainid == ANVIL_CHAIN_ID) {
            VRFCoordinatorV2_5Mock(config.vrfCoordinator).addConsumer(config.subscriptionId, address(raffle));
        }
        vm.stopBroadcast();

        return (raffle, helperConfig);
    }
}
