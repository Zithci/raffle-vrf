// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "../src/Raffle.sol";
import {VRFCoordinatorV2_5Mock} from "chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

// re-declare file-level errors so we can use .selector in expectRevert
error NotEnoughEthEntered();
error RaffleNotOpen();

contract RaffleTest is Test {
    Raffle public raffle;
    VRFCoordinatorV2_5Mock public vrfCoordinator;

    uint256 constant ENTRANCE_FEE = 0.01 ether;
    uint256 constant INTERVAL = 30; // seconds
    bytes32 constant KEY_HASH = bytes32(0);

    uint256 subscriptionId;

    function setUp() public {
        // Deploy mock coordinator (baseFee, gasPrice, weiPerUnitLink)
        vrfCoordinator = new VRFCoordinatorV2_5Mock(0, 0, 1);

        subscriptionId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subscriptionId, 10 ether);

        raffle = new Raffle(ENTRANCE_FEE, INTERVAL, KEY_HASH, subscriptionId, address(vrfCoordinator));

        vrfCoordinator.addConsumer(subscriptionId, address(raffle));
    }

    // ─────────────────────────────────────────────────────────────
    // enterRaffle
    // ─────────────────────────────────────────────────────────────

    function test_enterRaffle_addsPlayer() public {
        address player = makeAddr("player");
        vm.deal(player, 1 ether);

        vm.prank(player);
        raffle.enterRaffle{value: ENTRANCE_FEE}();

        assertEq(raffle.getPlayers(0), player);
    }

    function test_enterRaffle_revertsWithNotEnoughETH() public {
        address player = makeAddr("player");
        vm.deal(player, 1 ether);

        vm.prank(player);
        vm.expectRevert(NotEnoughEthEntered.selector);
        raffle.enterRaffle{value: 0}();
    }

    // ─────────────────────────────────────────────────────────────
    // Reverts enterRaffle when calculating
    // ─────────────────────────────────────────────────────────────

    // ─────────────────────────────────────────────────────────────
    // Fuzz
    // ─────────────────────────────────────────────────────────────

    function testFuzz_enterRaffle_revertsIfInsuficientFee(uint96 amount) public {
    vm.assume(amount < ENTRANCE_FEE); // filter amount from foundry 0.001
        address player = makeAddr("fuzzer"); //generate deterministic address from the string
        vm.deal(player, ENTRANCE_FEE); //give player enough eth to send tx

        vm.prank(player); 
        vm.expectRevert(NotEnoughEthEntered.selector); // err detail
        raffle.enterRaffle{value:amount}();
    }

    function test_enterRaffle_revertsWhenCalculating() public {
        address player1 = makeAddr("player1");
        address player2 = makeAddr("player2");
        vm.deal(player1, 1 ether);  
        vm.deal(player2, 1 ether);

        vm.prank(player1);
        raffle.enterRaffle{value: ENTRANCE_FEE}();

        vm.warp(block.timestamp + INTERVAL + 1);
        raffle.performUpkeep(new bytes(0));

        vm.prank(player2);
        vm.expectRevert(RaffleNotOpen.selector);
        raffle.enterRaffle{value: ENTRANCE_FEE}();
    }

    // ─────────────────────────────────────────────────────────────
    // performUpkeep(new bytes(0))   // ─────────────────────────────────────────────────────────────

    function test_chooseWinner_revertsBeforeIntervalPasses() public {
        address player = makeAddr("player");
        vm.deal(player, 1 ether);

        vm.prank(player);
        raffle.enterRaffle{value: ENTRANCE_FEE}();

        // interval hasn't passed yet
        vm.expectRevert(RaffleNotOpen.selector);
        raffle.performUpkeep(new bytes(0));
    }

    // ─────────────────────────────────────────────────────────────
    // verifyin the winner get the prize
    // ─────────────────────────────────────────────────────────────

    function test_winnerReceivesAllFunds() public {
        // Enter 3 players
        address[] memory players = new address[](3);
        for (uint256 i = 0; i < 3; i++) {
            players[i] = makeAddr(string(abi.encodePacked("p", i)));
            vm.deal(players[i], 1 ether);
            vm.prank(players[i]);
            raffle.enterRaffle{value: ENTRANCE_FEE}();
        }

        uint256 totalPrize = ENTRANCE_FEE * 3;

        vm.warp(block.timestamp + INTERVAL + 1);
        raffle.performUpkeep(new bytes(0)); // requestId = 1 (mock starts at 1)

        // randomWord = 0 → winnerIndex = 0 % 3 = 0 → players[0] wins
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 0;

        uint256 balanceBefore = players[0].balance;
        vrfCoordinator.fulfillRandomWordsWithOverride(1, address(raffle), randomWords);

        // winner got the prize
        assertEq(players[0].balance, balanceBefore + totalPrize);
        // raffle is drained
        assertEq(address(raffle).balance, 0);
    }

    // ─────────────────────────────────────────────────────────────
    // calculating the index
    // ─────────────────────────────────────────────────────────────

    function test_winnerIndex_usesModulo() public {
        // Enter 3 players, randomWord = 7 → 7 % 3 = 1 → players[1] wins
        address[] memory players = new address[](3);
        for (uint256 i = 0; i < 3; i++) {
            players[i] = makeAddr(string(abi.encodePacked("q", i)));
            vm.deal(players[i], 1 ether);
            vm.prank(players[i]);
            raffle.enterRaffle{value: ENTRANCE_FEE}();
        }

        vm.warp(block.timestamp + INTERVAL + 1);
        raffle.performUpkeep(new bytes(0));

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 7; // 7 % 3 = 1

        uint256 balanceBefore = players[1].balance;
        vrfCoordinator.fulfillRandomWordsWithOverride(1, address(raffle), randomWords);

        assertEq(players[1].balance, balanceBefore + ENTRANCE_FEE * 3);
    }

    // ─────────────────────────────────────────────────────────────
    //  reset the winner list - clear the list
    // ─────────────────────────────────────────────────────────────

    function test_stateResetsAfterWinner() public {
        address player1 = makeAddr("player1");
        address player2 = makeAddr("player2");
        vm.deal(player1, 1 ether);
        vm.deal(player2, 1 ether);

        vm.prank(player1);
        raffle.enterRaffle{value: ENTRANCE_FEE}();

        vm.warp(block.timestamp + INTERVAL + 1);
        raffle.performUpkeep(new bytes(0));

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 0;
        vrfCoordinator.fulfillRandomWordsWithOverride(1, address(raffle), randomWords);

        // after winner picked: state is OPEN, players array is empty
        // player2 should be able to enter and be at index 0
        vm.prank(player2);
        raffle.enterRaffle{value: ENTRANCE_FEE}();
        assertEq(raffle.getPlayers(0), player2);
    }
}
