// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title  A simple Lottery Contract
 * @author Vivek Nath
 * @notice This is the simple lottery contract
 * @dev implementations fof chainlink vrf
 */
import {VRFConsumerBaseV2Plus} from "chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract Raffle is VRFConsumerBaseV2Plus {
    error NotEnoughFee();
    error TransferFailed();
    error RaffleNotOpen();
    error Raffle__upKeepNeeded(uint256 balance, uint256 playerLength, uint256 raffleState);

    enum RaffleState {
        OPEN, //0
        CALCULATING //1

    }

    bytes32 private immutable i_keyHash;
    uint32 private constant NUM_WORDS = 1;
    uint32 private immutable i_callbackGasLimit;
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    uint256 private s_lastTimeStamp;
    uint256 private immutable i_subscription_Id;
    uint16 private constant REQUEST_CONFIRMATIONS = 1;
    RaffleState private s_raffleState;

    address payable[] public s_lotteryPlayers;
    address private s_Winner;

    /*Events */

    event EnteredRaffle(address indexed player);
    event WinnerSelected(address indexed winner);
    event RequestRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        // s_vrfCoordinator.requestRandomWords();
        i_keyHash = gasLane;
        i_subscription_Id = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) {
            revert NotEnoughFee();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert RaffleNotOpen();
        }
        s_lotteryPlayers.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    function checkUpkeep(bytes memory /*checkData*/ )
        public
        view
        returns (bool upKeepNeeded, bytes memory /*performData*/ )
    {
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) >= i_interval);
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayer = s_lotteryPlayers.length > 0;
        upKeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayer;
        return (upKeepNeeded, "0x0");
    }

    function performUpkeep(bytes calldata /*performData*/ ) public {
        (bool upKeepNeeded,) = checkUpkeep("");
        if (!upKeepNeeded) {
            revert Raffle__upKeepNeeded(address(this).balance, s_lotteryPlayers.length, uint256(s_raffleState));
        }

        s_raffleState = RaffleState.CALCULATING;

        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscription_Id,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );

        emit RequestRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256,
        /*requestId*/
        uint256[] calldata randomWords
    ) internal override {
        // Step 1: Determine the winner
        uint256 indexOfPlayer = randomWords[0] % s_lotteryPlayers.length;
        address payable winner = s_lotteryPlayers[indexOfPlayer];

        // Step 2: Update state variables before making the external call
        s_Winner = winner; // Set the winner address
        s_raffleState = RaffleState.OPEN; // Change the raffle state to OPEN
        s_lotteryPlayers = new address payable[](0); // Reset the list of lottery players
        s_lastTimeStamp = block.timestamp; // Update the timestamp of the last raffle

        // Step 4: Emit an event to log the winner selection
        emit WinnerSelected(winner);

        // Step 3: Transfer the prize to the winner
        (bool successfulTransfer,) = winner.call{value: address(this).balance}("");
        if (!successfulTransfer) {
            revert TransferFailed();
        }
    }

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOf) external view returns (address) {
        return s_lotteryPlayers[indexOf];
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns (address) {
        return s_Winner;
    }
}
