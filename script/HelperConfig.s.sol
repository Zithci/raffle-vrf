    //SPDX-License-Identifier:MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
uint256 constant SEPOLIA_CHAIN_ID = 11155111;
uint256 constant ANVIL_CHAIN_ID = 31337;

contract HelperConfig is Script {
    struct NetworkConfig{
    uint256 entranceFee;
    uint256 interval;
    bytes32 keyHash; 
    uint256 subscriptionId; 
    address vrfCoordinator;
}

function getSepoliaConfig() public pure returns(NetworkConfig memory){
    return NetworkConfig({
          entranceFee: 0.01 ether,
          interval: 30,
          keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
          subscriptionId: 22846719830693304606197796748300312292966888493473627927537967300861687365588,    
          vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B
      });
}

function getAnvilConfig() public returns (NetworkConfig memory){
    if(activeNetworkConfig.vrfCoordinator != address(0)){
        return activeNetworkConfig;
    }
    vm.startBroadcast();
    VRFCoordinatorV2_5Mock mockCoordinator = new VRFCoordinatorV2_5Mock(
        0.25 ether,  // baseFee
        1e9,         // gasPrice (1 gwei)
        4e15         // weiPerUnitLink
    );
    uint256 subId = mockCoordinator.createSubscription();
    mockCoordinator.fundSubscription(subId, 10 ether);
    vm.stopBroadcast();

    return NetworkConfig({
        entranceFee :0.01 ether,
        interval : 30,
        keyHash : 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
        subscriptionId :subId,
        vrfCoordinator: address(mockCoordinator)
    });
}

function getActiveNetworkConfig()public view returns (NetworkConfig memory){
    return activeNetworkConfig;
}

    NetworkConfig public activeNetworkConfig;

    // mapping(uint256 => NetworkConfig ) public networkConfig;
    constructor(){
        if(block.chainid == SEPOLIA_CHAIN_ID){
            activeNetworkConfig = getSepoliaConfig();
        }else if(block.chainid == ANVIL_CHAIN_ID ){
            activeNetworkConfig = getAnvilConfig();
        }
    }

}