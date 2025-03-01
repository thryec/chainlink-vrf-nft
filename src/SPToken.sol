// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title SPToken
 * @dev ERC20 token for SP NFT staking rewards
 */
contract SPToken is ERC20, Ownable {
    // The address of the staking contract authorized to mint tokens
    address public stakingContract;

    // Event for when the staking contract is set
    event StakingContractSet(address indexed stakingContract);

    /**
     * @dev Constructor to initialize the SPToken contract
     * @param _name The name of the token
     * @param _symbol The symbol of the token
     */
    constructor(
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) Ownable(msg.sender) {}

    /**
     * @dev Function to set the staking contract address
     * @param _stakingContract The address of the staking contract
     */
    function setStakingContract(address _stakingContract) external onlyOwner {
        stakingContract = _stakingContract;
        emit StakingContractSet(_stakingContract);
    }

    /**
     * @dev Function to mint tokens - can only be called by the staking contract
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external {
        require(
            msg.sender == stakingContract,
            "Only the staking contract can mint tokens"
        );
        _mint(to, amount);
    }

    /**
     * @dev Function to burn tokens
     * @param amount The amount of tokens to burn
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
