// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// imports
import { CustomOwnable } from "./imports/CustomOwnable.sol";
import { ERC721A } from "./imports/ERC721A.sol";
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Pausable } from "@openzeppelin/contracts/security/Pausable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Address } from "./libs/Address.sol";
import { IValidation } from "./libs/IValidation.sol";

/**
 * @title BoostingFarm
 * @dev BoostingFarm is an ERC721A contract that allows minting of NFTs with tier-based boosting features. 
 * 721A is Azuki's pattern with royalities and gas-efficient enumerable logic.
 * Each tier has specific parameters including price, wallet limit, boosting intervals, and rates.
 * The contract integrates with ERC20 tokens for payments and uses a modular approach with separation of concerns.
 * It supports pausing, reentrancy protection, and restricted token transfers.
 * The contract includes mechanisms for managing tiers, calculating rewards, and validating token ownership.
 */

contract BoostingFarm is ERC721A, CustomOwnable, Pausable, ReentrancyGuard  {
    using SafeERC20 for IERC20;
    using Address for address;
    using IValidation for address;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.UintSet;

    uint256 public constant ZERO = 0;
    uint256 public constant ONE = 1;
    uint256 public constant EXP_RATE_FACTOR = 100;
    uint256 public constant EXP_MAX_RATE_FACTOR = 10_000;
    uint256 public constant THOUSAND = 1_000;
    uint256 public constant MIN_TIER_ID = 1;
    uint256 public constant MAX_SUPPLY = 1_000_000;
    uint256 public constant THRESHOLD = 10;

    struct TierSchedule {
        IERC20 paymentToken;
        string name;
        string uri;
        uint256 tierPrice;
        uint256 walletLimit;
        uint256 boostingInterval;
        uint256 boostingRate;
        uint256 boostResetInterval;
        uint256 totalMinted;
        uint256 totalAmount;
        bool active;
    }

    struct TokenInfo {
        uint256 tierId;
        uint256 mintTime;
        uint256 endBoostTime;
        bool isValidTierToken;
    }

    uint256 private _nextTierId;
    uint256 public maxWalletLimit = 100;
    uint256 public maxBoostingInterval = 15 days;
    uint256 public maxBoostTimer = 60 seconds;

    mapping(uint256 => TokenInfo) public tokenInfos;
    mapping(uint256 => TierSchedule) public tierSchedules;
    mapping(uint256 => mapping(address => uint256)) private _mintedPerWalletPerTier;
    mapping(uint256 => uint256) public tokenMintTime;
    mapping(uint256 => uint256) public tokenEndBoostTime;
    mapping(uint256 => uint256) public tokenTier;
    
    EnumerableSet.Bytes32Set private _tierNames;
    mapping(uint256 => EnumerableSet.UintSet) private _tierTokens;
    mapping(address => EnumerableSet.UintSet) private _ownedTokens;
    mapping(uint256 => mapping(uint256 => bool)) private _validateTokenTiers;

    // Events
    event VaultContractSettled(address indexed _initialVaultContract);
    event TierAdded(uint256 indexed _tierId, string _name, uint256 _boostResetInterval);
    event TierStarted(uint256 indexed _tierId, string _name);
    event TierPaused(uint256 indexed _tierId, string _name);
    event TierUnPaused(uint256 indexed _tierId, string _name);
    event ThresholdForBlocksUpdated(uint256 indexed _threshold);
    event TokenMinted(uint256 indexed _tierId, address indexed _user, uint256 indexed _quantity);
    event NativeTokenReceived(address indexed _sender, uint256 indexed _amount);
    event Withdrawal(address indexed owner, address indexed destination, uint256 indexed amount);

    // Errors
    error InvalidSupportInterface();
    error InvalidThreshold();
    error OnlyEOAAllowed();
    error SameContractUpdate();
    error TokensAreNotAllowedToTransfer();
    error InvalidAddressInteraction();
    error InvalidContractInteraction();
    error TierNotFound();
    error UpdatingTheSameAddress();
    error TokenAmountIsZero();
    error IncorrectFundsSent();
    error MaximumSupplyReached();
    error FailedToSend();
    error ERC20TransferFailed(address from, address to, uint256 amount);
    error TokenNotExist();
    error InvalidPaymentToken();
    error InvalidPrice();
    error InvalidWalletLimit();
    error InvalidBoostingInterval();
    error InvalidBoostRate();
    error InvalidMaxSupplyCap();
    error InvalidBoostTimer();
    error TierNameNotUnique();
    error TierIsNotActive();
    error TierAlreadyStarted();
    error OutOfBounds();
    error NotPermitted();

    modifier onlyEOA() {
        address caller = msg.sender;
        if(caller.isContract()) revert OnlyEOAAllowed();
        _;
    }

    modifier validContract(address _address) {
        if(!_address.isContract()) {
            revert InvalidContractInteraction();
        }
        _;
    }

    modifier validAddress(address _address){
        if(_address == address(0)){
            revert InvalidAddressInteraction();
        }
        _;
    }

    /* setup -------------------------------------------------------------------------------------- */
    
    /**
     * @dev Initializes the contract by setting a name and a symbol for the token collection.
     */
    constructor() ERC721A("Booster", "BoostingFarm") {
        _currentIndex = _startTokenId();
        _nextTierId = MIN_TIER_ID - 1;
    }

    receive() external payable {
        emit NativeTokenReceived(msg.sender, msg.value);
    }

    fallback() external payable {
        revert NotPermitted();
    }

    /* mechanics -----------------------------------------------------------------------------------*/

    /**
     * @dev Overrides the starting token ID to start from 1000.
     * @return uint256 The starting token ID.
     */
    function _startTokenId() internal pure override returns (uint256) {
        return THOUSAND;
    }

    /**
     * @dev Overrides the base URI for computing {tokenURI}.
     * @return string The base URI.
     */
    function _baseURI() internal pure override returns (string memory) {
        return "";
    }
    
    /**
     * @dev Returns the URI for a given token ID.
     * @param tokenId The token ID.
     * @return string The token URI.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if(!_exists(tokenId)) revert TokenNotExist();

        uint256 tierId = tokenTier[tokenId];
        if(tierId == ZERO || tierId > _nextTierId || !tierSchedules[tierId].active) revert TierNotFound();

        return tierSchedules[tierId].uri;
    }

    /**
     * @notice Mints a new token.
     * @param _tierId The ID of the tier.
     * @param _quantity The quantity of tokens to mint.
     */
     function safeMint(uint256 _tierId, uint256 _quantity) 
     external payable 
     nonReentrant() 
     onlyEOA() 
     whenNotPaused() 
    {
        if (_tierId == ZERO || _tierId > _nextTierId) revert TierNotFound();
        if (_quantity == ZERO) revert TokenAmountIsZero();
    
        TierSchedule storage tier = tierSchedules[_tierId];
        if (!tier.active) revert TierIsNotActive();
    
        uint256 totalMinted = _totalMinted();
        if (totalMinted + _quantity > MAX_SUPPLY) revert MaximumSupplyReached();
    
        uint256 cost = tier.tierPrice * _quantity;
    
        if (address(tier.paymentToken) == address(0)) {
            if (msg.value != cost) revert IncorrectFundsSent();
        } else {
            if (msg.value > ZERO) {
                revert IncorrectFundsSent();
            }
            tier.paymentToken.safeTransferFrom(_msgSender(), address(this), cost);
        }
    
        uint256 mintedForWallet = _mintedPerWalletPerTier[_tierId][_msgSender()] + _quantity;
        if (mintedForWallet > tier.walletLimit && tier.walletLimit != ZERO) revert InvalidWalletLimit();
    
        uint256 startTokenId = _currentIndex;
        _safeMint(_msgSender(), _quantity);
    
        unchecked {
            uint256 currentTime = block.timestamp;
            for (uint256 i = 0; i < _quantity; i++) {
                uint256 tokenId = startTokenId + i;
                tokenTier[tokenId] = _tierId;
                tokenInfos[tokenId] = TokenInfo({
                    tierId: _tierId,
                    mintTime: currentTime,
                    endBoostTime: currentTime + tier.boostResetInterval,
                    isValidTierToken: true
                });
                assert(_exists(tokenId));
            }
        }
        
        tier.totalMinted += _quantity;
        _mintedPerWalletPerTier[_tierId][_msgSender()] = mintedForWallet;
    
        emit TokenMinted(_tierId, _msgSender(), _quantity);
    }

    /**
     * @notice Calculates the reward for a specific token.
     * @param tokenId The token ID.
     * @return uint256 The reward amount.
     */
     function calculateRewardForToken(uint256 tokenId) public view returns (uint256) {
        if (!_exists(tokenId)) revert TokenNotExist();
    
        TokenInfo memory tokenInfo = tokenInfos[tokenId];
        uint256 endBoostTime = tokenInfo.endBoostTime;
    
        if (block.timestamp > endBoostTime + THRESHOLD) { 
            return ZERO;
        }
    
        TierSchedule memory tier = tierSchedules[tokenInfo.tierId];
    
        if(tier.boostingRate == ZERO) return ZERO;
    
        uint256 timeElapsed = block.timestamp - tokenInfo.mintTime;
        uint256 fullIntervals = timeElapsed / tier.boostingInterval;
    
        return fullIntervals * tier.boostingRate / EXP_RATE_FACTOR;
    }
    
    /**
     * @notice Calculates the total rewards for a specific owner.
     * @param owner The owner's address.
     * @return uint256 The total reward amount.
     */
     function calculateTotalRewardsForOwner(address owner) external view returns (uint256) {
        uint256 totalReward = ZERO;
        EnumerableSet.UintSet storage ownerTokensStorage = _ownedTokens[owner];
    
        uint256 length = ownerTokensStorage.length();
        for (uint256 i = 0; i < length; i++) {
            uint256 tokenId = ownerTokensStorage.at(i);
            totalReward += calculateRewardForToken(tokenId);
        }
        return totalReward;
    }
    
    
    /* getters ------------------------------------------------------------------------------------ */

    /**
     * @notice Gets the details of a tier.
     * @param tierId The tier ID.
     * @return TierSchedule The tier details.
     */
    function getTierDetails(uint256 tierId) external view returns (TierSchedule memory) {
        if (tierId == ZERO || tierId > _nextTierId) revert TierNotFound();
        return tierSchedules[tierId];
    }
    
    /**
     * @notice Gets the number of tokens minted by a specific wallet for a specific tier.
     * @param tierId The tier ID.
     * @param wallet The wallet address.
     * @return uint256 The number of tokens minted.
     */
    function getMintedCountByWallet(uint256 tierId, address wallet) external view returns (uint256) {
        if (wallet == address(0)) revert InvalidAddressInteraction();
        if (tierId == ZERO || tierId > _nextTierId) revert TierNotFound();
        return _mintedPerWalletPerTier[tierId][wallet];
    }

    /**
     * @notice Gets the tier ID of a specific token.
     * @param tokenId The token ID.
     * @return uint256 The tier ID.
     */
    function getTokenTier(uint256 tokenId) external view returns (uint256) {
        if (!_exists(tokenId)) revert TokenNotExist();
        return tokenTier[tokenId];
    }

    /**
     * @notice Gets the tokens for a specific tier.
     * @param _tierId The tier ID.
     * @return uint256[] The tokens in the tier.
     */
    function getTierTokens(uint256 _tierId) external view returns (uint256[] memory) {
        uint256 len = _tierTokens[_tierId].length();
        uint256[] memory tokens = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            tokens[i] = _tierTokens[_tierId].at(i);
        }
        return tokens;
    }

    /**
     * @notice Gets the number of tokens owned by a specific address.
     * @param owner The owner's address.
     * @return uint256 The number of tokens owned.
     */
    function getOwnedTokenCount(address owner) external view returns (uint256) {
        return _ownedTokens[owner].length();
    }

    /**
     * @notice Gets the tokens owned by a specific address.
     * @param owner The owner's address.
     * @return uint256[] The tokens owned.
     */
    function getOwnedTokens(address owner) external view returns (uint256[] memory) {
        EnumerableSet.UintSet storage ownerTokens = _ownedTokens[owner];
        uint256[] memory tokens = new uint256[](ownerTokens.length());
        for (uint256 i = 0; i < tokens.length; ++i) {
            tokens[i] = ownerTokens.at(i);
        }
        return tokens;
    }

    /**
     * @notice Gets the token owned by a specific address at a specific index.
     * @param owner The owner's address.
     * @param index The index.
     * @return uint256 The token ID.
     */
    function getOwnerTokenByIndex(address owner, uint256 index) external view returns (uint256) {
        EnumerableSet.UintSet storage ownerTokens = _ownedTokens[owner];
        if(index >= ownerTokens.length()) revert OutOfBounds();
        return ownerTokens.at(index);
    }

    /**
     * @notice Gets the information of a specific token.
     * @param _tokenId The token ID.
     * @return TokenInfo The token information.
     */
    function getTokenInfo(uint256 _tokenId) external view returns(TokenInfo memory){
        if (!_exists(_tokenId)) revert TokenNotExist();
        TokenInfo memory tokenInfo = tokenInfos[_tokenId];

        return tokenInfo;
    }
    
    /**
     * @notice Validates if a specific token exists.
     * @param _tokenId The token ID.
     * @return bool True if the token exists, false otherwise.
     */
    function getValidateToken(uint256 _tokenId) external view returns (bool) {
        return _exists(_tokenId);
    }

    /* hooks-- ----------------------------------------------------------------------------------- */

    /**
     * @dev Internal function to handle token transfers.
     * @param from The address from which the token is transferred.
     * @param to The address to which the token is transferred.
     * @param startTokenId The starting token ID.
     * @param quantity The quantity of tokens transferred.
     */
    function _afterTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal override {
        super._afterTokenTransfers(from, to, startTokenId, quantity);
    
        if (from == address(0)) {
            for (uint256 i = 0; i < quantity; i++) {
                uint256 tokenId = startTokenId + i;
                _ownedTokens[to].add(tokenId);
            }
        } else if (to == address(0)) {
            for (uint256 i = 0; i < quantity; i++) {
                uint256 tokenId = startTokenId + i;
                _ownedTokens[from].remove(tokenId);
            }
        } else { 
            for (uint256 i = 0; i < quantity; i++) {
                uint256 tokenId = startTokenId + i;
                _ownedTokens[from].remove(tokenId);
                _ownedTokens[to].add(tokenId);
            }
        }
    }
    
    /**
     * @dev Internal function to add a token to an owner.
     * @param owner The owner's address.
     * @param tokenId The token ID.
     */
    function _addTokenToOwner(address owner, uint256 tokenId) internal {
        EnumerableSet.UintSet storage ownerTokens = _ownedTokens[owner];
        ownerTokens.add(tokenId);
    }

    /**
     * @dev Internal function to remove a token from an owner.
     * @param owner The owner's address.
     * @param tokenId The token ID.
     */
    function _removeTokenFromOwner(address owner, uint256 tokenId) internal {
        EnumerableSet.UintSet storage ownerTokens = _ownedTokens[owner];
        ownerTokens.remove(tokenId);
    }

    /* setters ----------------------------------------------------------------------------------- */
    
    /* internals---------------------------------------------------------------------------------- */

    /**
     * @notice Disables token transfers.
     */
    function transferFrom(address /*from*/, address /*to*/, uint256 /*tokenId*/) public pure override {
        revert TokensAreNotAllowedToTransfer();
        //super.transferFrom(from, to, tokenId);
    }

    /**
     * @notice Disables safe token transfers.
     */
    function safeTransferFrom(address /*from*/, address /*to*/, uint256 /*tokenId*/) public pure override {
        revert TokensAreNotAllowedToTransfer();
        //super.safeTransferFrom(from, to, tokenId);
    }

    /**
     * @notice Disables safe token transfers with data.
     */
    function safeTransferFrom(
        address /*from*/, 
        address /*to*/, 
        uint256 /*tokenId*/, 
        bytes memory /*_data*/) 
        public pure override {
        revert TokensAreNotAllowedToTransfer();
        //super.safeTransferFrom(from, to, tokenId, _data);
    }

    /**
     * @dev Internal function to validate tier parameters.
     * @param _paymentToken The payment token address.
     * @param _name The name of the tier.
     * @param _tierPrice The price of the tier.
     * @param _walletLimit The wallet limit for the tier.
     * @param _boostingInterval The boosting interval for the tier.
     * @param _boostingRate The boosting rate for the tier.
     * @param _boostResetInterval The boost reset interval for the tier.
     */
    function _validateTierParameters(
        address _paymentToken,
        string memory _name,
        uint256 _tierPrice,
        uint256 _walletLimit,
        uint256 _boostingInterval,
        uint256 _boostingRate,
        uint256 _boostResetInterval
    ) internal view {
        if (_paymentToken != address(0) && (!_paymentToken.isContract() || !_paymentToken.validateERC20Token())) {
            revert InvalidPaymentToken();
        }
    
        if (_tierPrice == ZERO) {
            revert InvalidPrice();
        }
    
        if (_walletLimit > maxWalletLimit && _walletLimit != ZERO) {
            revert InvalidWalletLimit();
        }
    
        if (_boostingInterval > maxBoostingInterval || _boostingInterval < maxBoostTimer) {
            revert InvalidBoostingInterval();
        }
    
        if (_boostingRate < EXP_RATE_FACTOR || _boostingRate > EXP_MAX_RATE_FACTOR) {
            revert InvalidBoostRate();
        }
    
        if (_boostResetInterval < _boostingInterval || _boostResetInterval == ZERO) {
            revert InvalidBoostTimer();
        }
    
        if (_boostResetInterval / _boostingInterval * _walletLimit > MAX_SUPPLY) {
            revert InvalidMaxSupplyCap();
        }
    
        if (_tierNames.contains(keccak256(abi.encodePacked(_name)))) {
            revert TierNameNotUnique();
        }
    }
    
    /* administrator ----------------------------------------------------------------------------------- */

    /**
     * @notice Adds a new tier.
     * @param _paymentToken The payment token address.
     * @param _name The name of the tier.
     * @param _uri The URI of the tier.
     * @param _tierPrice The price of the tier.
     * @param _walletLimit The wallet limit for the tier.
     * @param _boostingInterval The boosting interval for the tier.
     * @param _boostingRate The boosting rate for the tier.
     * @param _boostResetInterval The boost reset interval for the tier.
     */
    function addTier(
        address _paymentToken, 
        string calldata _name, 
        string calldata _uri, 
        uint256 _tierPrice,
        uint256 _walletLimit,
        uint256 _boostingInterval,
        uint256 _boostingRate, 
        uint256 _boostResetInterval
    ) external onlyOwner() {
        _validateTierParameters(
            _paymentToken, 
            _name, 
            _tierPrice, 
            _walletLimit,
            _boostingInterval,
            _boostingRate,
            _boostResetInterval
        );

        _nextTierId += ONE;
        TierSchedule memory tierSchedule = TierSchedule({
            paymentToken: IERC20(_paymentToken),
            uri: _uri,
            name: _name,
            tierPrice: _tierPrice,
            walletLimit: _walletLimit,
            boostingInterval: _boostingInterval,
            boostingRate: _boostingRate,
            boostResetInterval: _boostResetInterval,
            totalMinted: ZERO,
            totalAmount: ZERO,
            active: false
        });

        tierSchedules[_nextTierId] = tierSchedule;
        _tierNames.add(keccak256(abi.encodePacked(_name)));

        emit TierAdded(_nextTierId, _name, _boostResetInterval);
    }

    /**
     * @notice Starts a tier.
     * @param _tierId The tier ID.
     */
    function startTier(uint256 _tierId) external onlyOwner() {
        if (_tierId == ZERO || _tierId > _nextTierId) revert TierNotFound();
        TierSchedule storage tier = tierSchedules[_tierId];
        if(tier.active) revert TierAlreadyStarted();
        tier.active = true;
        emit TierStarted(_tierId, tier.name);
    }

    /**
     * @notice Switches the status of a tier.
     * @param _tierId The tier ID.
     * @param _active The new status of the tier.
     */
    function switchTierStatus(uint256 _tierId, bool _active) external onlyOwner() {
        if (_tierId == ZERO || _tierId > _nextTierId) revert TierNotFound();
        TierSchedule storage tier = tierSchedules[_tierId];
        tier.active = _active;
        if(_active) emit TierUnPaused(_tierId, tier.name);
        else emit TierPaused(_tierId, tier.name);
    }
    
    /**
     * @notice Rescues tokens from the contract.
     * @param _tokenAddress The address of the token to rescue.
     * @param _to The address to send the rescued tokens to.
     * @param _amount The amount of tokens to rescue.
     */
    function rescueTokens(address _tokenAddress, address _to, uint256 _amount) 
    external 
    validContract(_tokenAddress)
    validAddress(_to) 
    onlyOwner() 
    {
        if(_amount == 0) revert TokenAmountIsZero();
        SafeERC20.safeTransfer(IERC20(_tokenAddress), _to, _amount);
        emit Withdrawal(_tokenAddress, _to, _amount);
    }
    
    /**
     * @notice Withdraws native tokens from the contract.
     */
    function withdraw() external onlyOwner() {
        uint256 balance = address(this).balance;
        (bool success, ) = payable(owner()).call{value: balance}("");
        if(!success) revert FailedToSend();
    }

    /**
     * @notice Pauses the contract.
     */
    function pause() external onlyOwner() {
        _pause();
    }

    /**
     * @notice Unpauses the contract.
     */
    function unpause() external onlyOwner(){
        _unpause();
    }
}