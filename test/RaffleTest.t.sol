////SPDX-License-Identifier:MIT
pragma solidity 0.8.25;
import {Test} from "forge-std/Test.sol";
import {Raffle, NotEnoughEthEntered, RaffleNotOpen} from "../src/Raffle.sol";
import {DeployRaffle} from "../script/DeployRaffle.s.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {
    VRFCoordinatorV2_5Mock
} from "chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is Test {
    //declare var
    Raffle raffle;
    HelperConfig helperConfig;

    uint256 interval;
    uint256 entranceFee;
    uint256 subscriptionId;
    address vrfCoordinator;

    //set new player
    address geva = makeAddr("Geva");

    //set his balance
    uint256 public constant STARTING_BALANCE = 10 ether;

    //catch 2 returns
    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();

        HelperConfig.NetworkConfig memory config = helperConfig.getActiveNetworkConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        subscriptionId = config.subscriptionId;
        vrfCoordinator = config.vrfCoordinator;

        vm.deal(geva, STARTING_BALANCE);
    }

    function testEnterRaffle() public {
        vm.prank(geva);
        raffle.enterRaffle{value: entranceFee}();
        assert(raffle.getPlayers(0) == geva);
    }

    function testEntranceFee() public {
        vm.expectRevert(NotEnoughEthEntered.selector);
        vm.prank(geva);
        raffle.enterRaffle{value: 0.001 ether}();
    }

    function testTime() public {
        vm.warp(block.timestamp + interval + 1);
        for (uint256 i = 0; i < 100; i++) {
            address player = address(uint160(i + 1));
            vm.deal(player, 1 ether);
            vm.prank(player);
            raffle.enterRaffle{value: entranceFee}();
        }
        raffle.performUpkeep(new bytes (0));
        vm.expectRevert(RaffleNotOpen.selector);
        vm.prank(geva);
        raffle.enterRaffle{value: entranceFee}();
    }
}



