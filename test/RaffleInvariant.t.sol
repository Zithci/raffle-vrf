// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, StdInvariant} from "forge-std/Test.sol";
import {Raffle} from "../src/Raffle.sol";
import {VRFCoordinatorV2_5Mock} from
    "chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

// ─────────────────────────────────────────────────────────────
// Handler
// ─────────────────────────────────────────────────────────────
contract Handler is Test {
    Raffle public raffle;
    VRFCoordinatorV2_5Mock public vrfCoordinator;

    uint256 constant ENTRANCE_FEE = 0.01 ether;
    uint256 public lastRequestId;
    uint256 public requestCount;

    constructor(Raffle _raffle, VRFCoordinatorV2_5Mock _vrfCoordinator) {
        raffle = _raffle;
        vrfCoordinator = _vrfCoordinator;
    }

    function enterRaffle(uint256 playerSeed) public {
        address player = address(uint160(bound(playerSeed, 1, type(uint160).max)));
        if (player == address(raffle) || player == address(vrfCoordinator) || player == address(this)) return;
        vm.deal(player, ENTRANCE_FEE);
        vm.prank(player);
        try raffle.enterRaffle{value: ENTRANCE_FEE}() {} catch {}
    }

    function performUpkeep() public {
        vm.warp(block.timestamp + 31);
        (bool upkeepNeeded,) = raffle.checkUpkeep(new bytes(0));
        if (!upkeepNeeded) return;
        raffle.performUpkeep(new bytes(0));
        requestCount++;
        lastRequestId = requestCount;
    }

    function fulfillRandomWords() public {
        if (lastRequestId == 0) return;
        vrfCoordinator.fulfillRandomWords(lastRequestId, address(raffle));
        lastRequestId = 0;
    }
}

// ─────────────────────────────────────────────────────────────
// Invariant Test
// ─────────────────────────────────────────────────────────────
contract RaffleInvariantTest is StdInvariant, Test {
    Raffle public raffle;
    VRFCoordinatorV2_5Mock public vrfCoordinator;
    Handler public handler;

    uint256 constant ENTRANCE_FEE = 0.01 ether;
    uint256 constant INTERVAL = 30;
    bytes32 constant KEY_HASH = bytes32(0);
    uint256 subscriptionId;

    function setUp() public {
        vrfCoordinator = new VRFCoordinatorV2_5Mock(0, 0, 1);
        subscriptionId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subscriptionId, 10 ether);

        raffle = new Raffle(ENTRANCE_FEE, INTERVAL, KEY_HASH, subscriptionId, address(vrfCoordinator));
        vrfCoordinator.addConsumer(subscriptionId, address(raffle));

        handler = new Handler(raffle, vrfCoordinator);
        targetContract(address(handler));
    }

    function invariant_balanceMatchesPlayers() public view {
        assert(address(raffle).balance == raffle.getPlayersLength() * ENTRANCE_FEE);
    }
}
