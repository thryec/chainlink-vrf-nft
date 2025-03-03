// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StateZero.t.sol";
import "../src/VRFMock.sol";

/**
 * @title StakingDeployedState
 * @dev State with staking contracts deployed
 */
abstract contract StakingDeployedState is StateZero {
    SPNFTWithExposedVRF internal spnftWithVRF; // For in-collection revealed NFTs
    RevealedSPNFT internal revealedSpnft; // For separate collection revealed NFTs
    SPToken internal spToken;
    SPNFTStaking internal staking;

    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(deployer);

        // Deploy SP NFT (for in-collection reveals)
        spnftWithVRF = new SPNFTWithExposedVRF(
            "SP NFT",
            "SPNFT",
            mintPrice,
            maxSupply,
            mockVrfCoordinator,
            keyHash,
            subscriptionId
        );

        // Deploy RevealedSPNFT (for separate collection reveals)
        revealedSpnft = new RevealedSPNFT("Revealed SP NFT", "RSPNFT");

        // Set the SP NFT as the minter for RevealedSPNFT
        revealedSpnft.setSPNFTContract(address(spnftWithVRF));
        spnftWithVRF.setRevealedCollectionAddress(address(revealedSpnft));

        // Set in-collection reveal as default
        spnftWithVRF.setRevealType(SPNFT.RevealType.InCollection);

        // Deploy SPToken
        spToken = new SPToken("SP Token", "SPT");

        // Deploy staking contract with both NFT contracts
        staking = new SPNFTStaking(
            address(spnftWithVRF), // Original collection (in-collection reveals)
            address(revealedSpnft), // Revealed collection (separate collection reveals)
            address(spToken)
        );

        // Set the staking contract as the minter for SPToken
        spToken.setStakingContract(address(staking));

        // Set metadata for both NFT contracts
        spnftWithVRF.setMetadata(names, descriptions, images, attributes);
        revealedSpnft.setMetadata(names, descriptions, images, attributes);

        // Allow direct mints for testing purposes
        spnftWithVRF.setMintEnabled(true);

        vm.stopPrank();

        // Label contracts
        vm.label(address(spnftWithVRF), "SPNFT");
        vm.label(address(revealedSpnft), "RevealedSPNFT");
        vm.label(address(spToken), "SPToken");
        vm.label(address(staking), "SPNFTStaking");
    }

    /**
     * @dev Helper function to simulate VRF callback for in-collection reveals
     */
    function _simulateVRFCallback(
        uint256 requestId,
        uint256 randomness
    ) internal {
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = randomness;

        vm.prank(mockVrfCoordinator);
        spnftWithVRF.testFulfillRandomWords(requestId, randomWords);
    }
}

/**
 * @title StakingDeployedTest
 * @dev Tests for the initial staking deployment state
 */
contract StakingDeployedTest is StakingDeployedState {
    function testContractsDeployed() public {
        assertEq(spToken.name(), "SP Token");
        assertEq(spToken.symbol(), "SPT");
        assertEq(spToken.stakingContract(), address(staking));

        assertEq(revealedSpnft.name(), "Revealed SP NFT");
        assertEq(revealedSpnft.symbol(), "RSPNFT");

        // Check that staking contract was configured with both NFT addresses
        assertEq(address(staking.originalSPNFT()), address(spnftWithVRF));
        assertEq(address(staking.revealedSPNFT()), address(revealedSpnft));
        assertEq(address(staking.rewardToken()), address(spToken));
    }

    function testNothingStakedInitially() public {
        uint256[] memory originalTokens;
        uint256[] memory revealedTokens;

        (originalTokens, revealedTokens) = staking.getAllStakedTokens(user1);

        assertEq(originalTokens.length, 0);
        assertEq(revealedTokens.length, 0);
        assertEq(staking.getTotalStakedByOwner(user1), 0);
    }

    function testAPYRate() public {
        assertEq(staking.APY_RATE(), 5); // 5% APY
    }
}
