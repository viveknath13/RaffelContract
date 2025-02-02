// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";

import {VRFCoordinatorV2_5Mock} from "chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

import {LinkToken} from "test/mock/linkToken.sol";

abstract contract CodeConstants {
    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint96 public constant MOCK_GAS_PRICE_LINK = 1e9;
    int256 public constant MOCK_WEI_PER_UNIT = 4e15;

    uint256 public constant SEPOLIA_ETH_CHAIN = 11155111;
    uint256 public constant ANVIL_CHAIN = 31337;
}

error INVALID_CHAIN_ID();

contract HelperConfig is Script, CodeConstants {
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address linkToken;
        address account;
    }

    NetworkConfig public local_NetworkConfig;

    mapping(uint256 chainId => NetworkConfig) public networkConfig;

    constructor() {
        networkConfig[SEPOLIA_ETH_CHAIN] = getSepoliaEth();
    }

    function getChainConfig(uint256 chainId) public returns (NetworkConfig memory) {
        if (networkConfig[chainId].vrfCoordinator != address(0)) {
            return networkConfig[chainId];
        } else if (chainId == ANVIL_CHAIN) {
            return getOrCreateAnvilConfig();
        } else {
            revert INVALID_CHAIN_ID();
        }
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getChainConfig(block.chainid);
    }

    function getSepoliaEth() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: 0.01 ether, //1e16
            interval: 30, // 30 second
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: 0,
            callbackGasLimit: 5000,
            linkToken: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            account : 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
        });
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        if (local_NetworkConfig.vrfCoordinator != address(0)) {
            return local_NetworkConfig;
        }

        //Deploy mock

        vm.startBroadcast();

        new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UNIT);
        LinkToken link = new LinkToken();

        vm.stopBroadcast();

        local_NetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether, //1e16
            interval: 30, // 30 second
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: 0,
            callbackGasLimit: 5000,
            linkToken: address(link),
            account : 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
        });
        return local_NetworkConfig;
    }
}
