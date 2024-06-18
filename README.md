# Boosting NFT-Farm Smart Contract

## Overview

`Boosting NFT-Farm` is an ERC721A contract that allows minting of NFTs with tier-based boosting features. The contract supports multiple tiers with specific parameters including price, wallet limit, boosting intervals, and rates. It integrates with ERC20 tokens for payments or native tokens and ensures gas-efficient enumerable logic.

## ERC721A by Azuki

ERC721A is an improved version of the ERC721 standard introduced by Azuki. It optimizes gas usage for minting multiple NFTs in a single transaction, making it more efficient and cost-effective for both developers and users. This is particularly beneficial for large-scale NFT projects where gas fees can become a significant cost factor.

## ERC721A by me :)

In addition to the standard ERC721A features, `Boosting NFT-Farm` incorporates custom logic and enhancements specific to our requirements. These customizations include:

- **Tier-Based Minting:** Each tier has its own price, wallet limit, and boosting parameters.
- **Boosting Mechanism:** Tokens have a boosting interval and rate, allowing them to accrue rewards over time.
- **Restricted Transfers:** Token transfers are disabled to maintain the integrity of the tier-based boosting system.
- **Extended Metadata:** Each token is associated with additional metadata, such as mint time and end boost time.
- 
### Benefits of ERC721A

- **Gas Efficiency:** Reduces gas costs significantly when minting multiple tokens.
- **Scalability:** Enables large-scale minting operations to be more feasible.
- **Enumerable:** Maintains efficient token enumeration for tracking ownership and transfers.

### Custom Modifiers

- **onlyEOA:** Ensures that only externally owned accounts can call certain functions.
- **validContract:** Ensures the provided address is a valid contract address.
- **validAddress:** Ensures the provided address is not a zero address.

### Custom Functions

- **safeMint(uint256 _tierId, uint256 _quantity):** Mints `_quantity` number of tokens for a given `_tierId`. Requires payment in the specified ERC20 token or native currency.
- **calculateRewardForToken(uint256 tokenId):** Calculates the reward for a specific token.
- **calculateTotalRewardsForOwner(address owner):** Calculates the total rewards for a specific owner.
- **addTier(...)**: Adds a new tier with specified parameters.
- **startTier(uint256 _tierId):** Starts a specific tier.
- **switchTierStatus(uint256 _tierId, bool _active):** Switches the status of a specific tier.
- **rescueTokens(address _tokenAddress, address _to, uint256 _amount):** Rescues tokens from the contract.
- **withdraw():** Withdraws native tokens from the contract.
- **pause():** Pauses the contract.
- **unpause():** Unpauses the contract.

## Features

- **Tier Management:** Each tier has a unique set of parameters.
- **Boosting:** Tokens can boost their rewards based on tier settings.
- **Pausable:** Contract functions can be paused for security.
- **Reentrancy Guard:** Protection against reentrancy attacks.
- **Ownership:** Only the contract owner can execute certain functions.
- **ERC20 Integration:** Payments can be made with ERC20 tokens.

## Usage

### Constructor

The contract constructor initializes the token collection with the name "Booster" and the symbol "BoostingFarm".

### Public Functions

- `safeMint(uint256 _tierId, uint256 _quantity)`: Mints `_quantity` number of tokens for a given `_tierId`. Requires payment in the specified ERC20 token or native currency.
- `calculateRewardForToken(uint256 tokenId)`: Calculates the reward for a specific token.
- `calculateTotalRewardsForOwner(address owner)`: Calculates the total rewards for a specific owner.

### Administrative Functions

- `addTier(...)`: Adds a new tier with specified parameters.
- `startTier(uint256 _tierId)`: Starts a specific tier.
- `switchTierStatus(uint256 _tierId, bool _active)`: Switches the status of a specific tier.
- `rescueTokens(address _tokenAddress, address _to, uint256 _amount)`: Rescues tokens from the contract.
- `withdraw()`: Withdraws native tokens from the contract.
- `pause()`: Pauses the contract.
- `unpause()`: Unpauses the contract.

### Events

- `VaultContractSettled(address indexed _initialVaultContract)`
- `TierAdded(uint256 indexed _tierId, string _name, uint256 _boostResetInterval)`
- `TierStarted(uint256 indexed _tierId, string _name)`
- `TierPaused(uint256 indexed _tierId, string _name)`
- `TierUnPaused(uint256 indexed _tierId, string _name)`
- `ThresholdForBlocksUpdated(uint256 indexed _threshold)`
- `TokenMinted(uint256 indexed _tierId, address indexed _user, uint256 indexed _quantity)`
- `NativeTokenReceived(address indexed _sender, uint256 indexed _amount)`
- `Withdrawal(address indexed owner, address indexed destination, uint256 indexed amount)`

### Errors

- `InvalidSupportInterface()`
- `InvalidThreshold()`
- `OnlyEOAAllowed()`
- `SameContractUpdate()`
- `TokensAreNotAllowedToTransfer()`
- `InvalidAddressInteraction()`
- `InvalidContractInteraction()`
- `TierNotFound()`
- `UpdatingTheSameAddress()`
- `TokenAmountIsZero()`
- `IncorrectFundsSent()`
- `MaximumSupplyReached()`
- `FailedToSend()`
- `ERC20TransferFailed(address from, address to, uint256 amount)`
- `TokenNotExist()`
- `InvalidPaymentToken()`
- `InvalidPrice()`
- `InvalidWalletLimit()`
- `InvalidBoostingInterval()`
- `InvalidBoostRate()`
- `InvalidMaxSupplyCap()`
- `InvalidBoostTimer()`
- `TierNameNotUnique()`
- `TierIsNotActive()`
- `TierAlreadyStarted()`
- `OutOfBounds()`
- `NotPermitted()`

## Mechanics

### Token Minting

Tokens can be minted by calling the `safeMint` function with the desired tier ID and quantity. Payment can be made in the specified ERC20 token or native currency, depending on the tier's configuration.

### Reward Calculation

The contract provides functions to calculate rewards for individual tokens and total rewards for a specific owner based on the boosting intervals and rates defined in the tier settings.

### Tier Management

The contract owner can add new tiers, start tiers, and switch the status of tiers (active/inactive). Each tier has a unique set of parameters including payment token, price, wallet limit, boosting intervals, and rates.

### Token Transfers

Token transfers are disabled to maintain the integrity of the tier-based boosting mechanism.

## Getting Tier and Token Information

- `getTierDetails(uint256 tierId)`: Retrieves details of a specific tier.
- `getMintedCountByWallet(uint256 tierId, address wallet)`: Retrieves the number of tokens minted by a specific wallet for a specific tier.
- `getTokenTier(uint256 tokenId)`: Retrieves the tier ID of a specific token.
- `getTierTokens(uint256 _tierId)`: Retrieves the tokens for a specific tier.
- `getOwnedTokenCount(address owner)`: Retrieves the number of tokens owned by a specific address.
- `getOwnedTokens(address owner)`: Retrieves the tokens owned by a specific address.
- `getOwnerTokenByIndex(address owner, uint256 index)`: Retrieves the token owned by a specific address at a specific index.
- `getTokenInfo(uint256 _tokenId)`: Retrieves the information of a specific token.
- `getValidateToken(uint256 _tokenId)`: Validates if a specific token exists.

## License

This project is licensed under the MIT License.

## Contributing

Contributions to expand or improve the repository are welcome! 

[@denizumutdereli](https://www.linkedin.com/in/denizumutdereli)

And please have a check other series of contracts that I have built for [@lasmetaio](https://github.com/lasmetaio)

