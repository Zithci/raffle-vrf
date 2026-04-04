//comtract Layout
// 1. version (pragma)
// 2. imports
// 3. errors
// 4. interfaces/libraries/contracts
// 5. type declarations
// 6. state variables
// 7. events
// 8. modifiers
// 9. functions

// function Layout
// 1. constructor
// 2. receive (kalau ada)
// 3. fallback (kalau ada)
// 4. external
// 5. public
// 6. internal
// 7. private
// 8. view/pure

// ________________
//Version.
//SPDX-License-Identifier:MIT
pragma solidity ^0.8.24;

//importing

import {VRFConsumerBaseV2Plus} from "chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

// declare errors
error NotEnoughEthEntered();
error RaffleNotOpen();

//** */
/**
 * @title a raffle.
 *@author geva
 *@notice  just wanna play with VRF.
 *@dev simple raffle with VRF
 */

//define the contract
contract Raffle is VRFConsumerBaseV2Plus {
    // 5. type declarations
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    //define state var
    uint256 private immutable i_entranceFee;
    uint256 private constant TOTAL_TICKETS = 100;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    uint256 private constant MAX_TICKETS_PER_PLAYER = 2;
    uint256 private immutable i_interval;

    //state for requesting random words at vrf
    bytes32 private i_keyHash;
    uint256 private subscription_Id;
    uint32 private constant CALL_BACK_GAS_LIMIT = 100000;
    uint32 private constant NUM_WORDS = 1;
    RaffleState private s_raffleState;

    //define events
    event playerEntered(address s_players, uint256 timestamp);
    event winnerPicked(address winner, uint256 timetamp);

    constructor(uint256 entranceFee, uint256 interval, bytes32 keyHash, uint256 subscriptionId, address vrfCoordinator)
        VRFConsumerBaseV2Plus(vrfCoordinator)
    {
        //assign params to state var
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_keyHash = keyHash;
        subscription_Id = subscriptionId;
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
    }

    function enterRaffle() external payable {
        if (s_raffleState != RaffleState.OPEN) revert RaffleNotOpen();
        if (msg.value < i_entranceFee) revert NotEnoughEthEntered();
        s_players.push(payable(msg.sender));
        emit playerEntered(msg.sender, block.timestamp);
    }

    function getPlayers(uint256 index) public view returns (address) {
        return s_players[index];
    }

    //rqst random words
    function ChooseWinner() external {
        if (s_players.length < TOTAL_TICKETS && block.timestamp - s_lastTimeStamp < i_interval) {
            revert RaffleNotOpen();
        }
        s_raffleState = RaffleState.CALCULATING;
        //requesting random words after all the terms are met
        s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: subscription_Id,
                requestConfirmations: 3,
                callbackGasLimit: CALL_BACK_GAS_LIMIT,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );
    }

    // modulo fulfill
    // adding CEI
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        // skip check
        // s_players.length > 0;

        //transfer(interaction) the balance to the winner
        uint256 winnerIndex = randomWords[0] % s_players.length;
        address payable winner = s_players[winnerIndex];

        //reset(effect)the array timestamp an the state
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
        emit winnerPicked(winner, block.timestamp);

        //transfer(interaction) the balance to the winner
        (bool success,) = winner.call{value: address(this).balance}("");
        if (!success) revert();
    }
}
