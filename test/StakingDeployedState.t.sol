// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.19;

// import "./StateZero.t.sol";

// /**
//  * @title StakingDeployedState
//  * @dev State with staking contracts deployed
//  */
// abstract contract StakingDeployedState is StateZero {
//     RevealedSPNFT internal revealedSpnft;
//     SPToken internal spToken;
//     SPNFTStaking internal staking;

//     function setUp() public virtual override {
//         super.setUp();

//         vm.startPrank(deployer);

//         // Deploy RevealedSPNFT
//         revealedSpnft = new RevealedSPNFT("Revealed SP NFT", "RSPNFT");

//         // Deploy SPToken
//         spToken = new SPToken("SP Token", "SPT");

//         // Deploy staking contract
//         staking = new SPNFTStaking(address(revealedSpnft), address(spToken));

//         // Set the staking contract as the minter for SPToken
//         spToken.setStakingContract(address(staking));

//         // Set metadata for RevealedSPNFT
//         revealedSpnft.setMetadata(names, descriptions, images, attributes);

//         // Allow direct mints for testing purposes
//         revealedSpnft.setSPNFTContract(deployer);

//         vm.stopPrank();

//         // Label contracts
//         vm.label(address(revealedSpnft), "RevealedSPNFT");
//         vm.label(address(spToken), "SPToken");
//         vm.label(address(staking), "SPNFTStaking");
//     }
// }

// /**
//  * @title StakingDeployedTest
//  * @dev Tests for the initial staking deployment state
//  */
// contract StakingDeployedTest is StakingDeployedState {
//     function testContractsDeployed() public {
//         assertEq(spToken.name(), "SP Token");
//         assertEq(spToken.symbol(), "SPT");
//         assertEq(spToken.stakingContract(), address(staking));

//         assertEq(revealedSpnft.name(), "Revealed SP NFT");
//         assertEq(revealedSpnft.symbol(), "RSPNFT");

//         assertEq(address(staking.revealedSPNFT()), address(revealedSpnft));
//         assertEq(address(staking.rewardToken()), address(spToken));
//     }

//     function testNothingStakedInitially() public {
//         uint256[] memory user1Stakes = staking.getStakedTokensByOwner(user1);
//         assertEq(user1Stakes.length, 0);
//     }

//     function testAPYRate() public {
//         assertEq(staking.APY_RATE(), 5); // 5% APY
//     }
// }
