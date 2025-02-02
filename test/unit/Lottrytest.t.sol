// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {VRFCoordinatorV2_5Mock} from "chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

import {Test, console} from "forge-std/Test.sol";

import {Raffle} from "../../src/Raffle.sol";
import {DeployScript} from "../../script/scripts.s.sol";
import {HelperConfig, CodeConstants} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {LinkToken} from "../mock/linkToken.sol";

contract Raffletest is Test, CodeConstants {
    event EnteredRaffle(address indexed player);
    event WinnerSelected(address indexed winner);

    Raffle public raffleContract;
    HelperConfig public helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint32 callbackGasLimit;
    uint256 subscriptionId;
    LinkToken linkToken;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_BALANCE = 10 ether;

    function setUp() external {
        DeployScript deployScript = new DeployScript();
        (raffleContract, helperConfig) = deployScript.run();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        console.log("VRF Coordinator: %s", config.vrfCoordinator);
        console.log("Entrance Fee: %s", config.entranceFee);
        console.log("Interval: %s", config.interval);
        console.log("Callback Gas Limit: %s", config.callbackGasLimit);
        console.log("Subscription ID: %s", config.subscriptionId);
        console.log("Link Token: %s", config.linkToken);

        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        callbackGasLimit = config.callbackGasLimit;
        subscriptionId = config.subscriptionId;
        linkToken = LinkToken(config.linkToken);
        vm.deal(PLAYER, STARTING_BALANCE);
    }

    modifier RaffleEntered() {
        vm.prank(PLAYER);

        raffleContract.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier skipFork(){
        if(block.chainid!=ANVIL_CHAIN){
            return ;
        }

        _;
    }

    function testRaffleInitializerInOpenState() public view {
        assert(raffleContract.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRevertEnoughETH() public {
        vm.prank(PLAYER);

        vm.expectRevert(Raffle.RaffleNotOpen.selector);
        raffleContract.enterRaffle{value: entranceFee }();
    }

    function testEnoughEthSend() public {
        vm.prank(PLAYER);
        raffleContract.enterRaffle{value: entranceFee}();
        address playerRecord = raffleContract.getPlayer(0);
        assert(playerRecord == PLAYER);
    }

    function testEvents() public {
        vm.prank(PLAYER);

        vm.expectEmit(true, false, false, false, address(raffleContract));
        emit EnteredRaffle(PLAYER);
        raffleContract.enterRaffle{value: entranceFee}();
    }

    function testDontAllowPlayerRaffleIsCalculating() public {
        //arrange
        vm.prank(PLAYER);

        raffleContract.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffleContract.performUpkeep("");

        //act
        vm.expectRevert(Raffle.RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffleContract.enterRaffle{value: entranceFee}();
    }

    function testCheckUpKeepReturnsFalseIfItHasEnoughBalance() public {
        //arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        //acct
        (bool upKeepNeeded,) = raffleContract.checkUpkeep("");
        assert(!upKeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIsRaffelIsOpen() public {
        //arrange
        vm.prank(PLAYER);

        raffleContract.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffleContract.performUpkeep("");
        //act
        (bool upKeepNeeded,) = raffleContract.checkUpkeep("");
        assert(!upKeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public {
        vm.prank(PLAYER);
        raffleContract.enterRaffle{value: entranceFee}();

        (bool upKeepNeeded,) = raffleContract.checkUpkeep("");

        assert(!upKeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenParametersGood() public {
        vm.prank(PLAYER);
        raffleContract.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        (bool upKeepNeeded,) = raffleContract.checkUpkeep("");
        assert(!upKeepNeeded);
    }

    function testPerformUpKeepCanOnlyRunIfCheckUpIsTrue() public {
        vm.prank(PLAYER);
        raffleContract.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffleContract.performUpkeep("");
    }

    function testCheckUpKeepIsRevertIsFalse() public {
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffleContract.getRaffleState();

        vm.prank(PLAYER);
        raffleContract.enterRaffle{value: entranceFee}();
        currentBalance = currentBalance + entranceFee;
        numPlayers = 1;

        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__upKeepNeeded.selector, currentBalance, numPlayers, rState)
        );
        raffleContract.performUpkeep("");
    }

    function testPerformUpKeepUpDatesRaffleStateAndEmitsRequestId() public RaffleEntered skipFork {
        vm.recordLogs();
        raffleContract.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        Raffle.RaffleState raffleState = raffleContract.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1);
    }

    function testFullFillrandomWordsCanOnlyCalledAfterCheckUpKeep(uint256 randomRequestId) public RaffleEntered skipFork {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffleContract));
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney() public RaffleEntered {
        //act
        uint256 additionalEntrants = 4; //Total player is 4
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

        for (uint256 i = startingIndex; i < additionalEntrants + 1; ++i) {
            address player = address(uint160(i));
            hoax(player, 1 ether);
            raffleContract.enterRaffle{value: entranceFee}();
        }
        uint256 timeStamp = raffleContract.getLastTimeStamp();
        uint256 WinnerStartingBalance = expectedWinner.balance;
        vm.recordLogs();
        raffleContract.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffleContract));

        address recentWinner = raffleContract.getRecentWinner();
        Raffle.RaffleState raffleState = raffleContract.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffleContract.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrants + 1);
        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == WinnerStartingBalance + prize);
        assert(timeStamp < endingTimeStamp);
    }
}
