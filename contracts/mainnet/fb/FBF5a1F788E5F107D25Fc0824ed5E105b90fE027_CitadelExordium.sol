// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract CitadelExordium is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using SafeMath for uint8;

    IERC20 public immutable drakma;
    IERC721 public immutable citadelCollection;

    struct TechTree {
        uint8 tech;
        uint8 techLevels; // 0 => 7, 1 => 9, 2 => 9, 3 => 7, 4 => 7, 5 => 3, 6 => 6, 7 => 5, 53 total
        uint256 researchCompleted;
        bool hasRelik;
    }

    uint256 private researchPerLevel = 7000000000000000000000000; //7M
    mapping(uint256 => TechTree) techTree; //0-7 annexation, 8-15 autonomous zone, 16-23 sanction, 24-31 network state

    // distribute 2.4 billion $drakma over 150 days pregame =>704,000 per hour
    struct Staker {
        uint256 amountStaked; // Sum of CITADEL staked * multiple
        uint256 timeOfLastUpdate;
        uint256 unclaimedRewards;
        uint8 techIndex;
        bool hasTech;
    }

    // Rewards are cumulated once every hour. Unit wei
    uint256 private rewardsPerHour = 166000000000000000000; //166 DK base / hr
    uint256 public periodFinish = 1674943200; //JAN 28 2023, 2PM PT 
    
    mapping(address => Staker) public stakers;
    mapping(uint256 => address) public stakerAddress;

    uint8[] public sektMultiple = [16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,16,4,4,2,2,4,2,4,2,4,8,2,2,2,4,2,4,4,2,4,4,2,4,8,4,2,2,2,2,2,2,8,8,2,4,8,8,2,2,2,4,4,2,4,2,8,4,4,4,2,8,2,4,2,4,4,8,4,2,2,2,2,2,4,8,2,4,4,2,2,2,2,8,4,4,8,2,2,2,4,8,2,2,2,4,8,4,2,2,2,2,4,2,4,2,4,2,4,2,2,2,4,4,2,2,2,2,2,2,2,4,2,2,2,8,2,2,2,4,4,4,4,4,4,2,2,4,4,8,2,2,2,2,4,2,2,2,2,2,2,2,2,2,8,2,4,2,2,4,2,2,8,2,2,2,2,4,4,2,4,2,2,2,4,2,2,8,8,2,4,2,4,2,2,2,2,4,2,4,4,4,8,2,4,4,2,4,4,4,2,2,2,2,2,4,4,4,2,4,8,2,4,2,4,2,4,2,2,8,4,4,4,2,4,2,8,2,8,2,8,2,4,2,4,4,8,4,2,2,2,2,8,4,4,2,8,2,4,2,2,4,2,8,2,2,2,4,2,4,2,8,2,4,2,2,8,8,4,2,2,2,8,2,8,2,2,2,2,4,8,2,2,2,2,2,2,2,2,8,4,2,2,2,2,2,2,2,2,2,4,2,4,2,2,2,4,2,2,2,8,8,4,2,2,4,2,4,4,2,2,2,2,2,4,2,8,4,2,4,4,2,2,2,2,2,2,2,2,4,2,2,4,4,4,2,2,2,4,2,8,2,2,2,4,2,2,4,2,8,2,4,2,2,2,4,2,8,2,2,2,2,8,2,2,4,2,2,2,2,2,4,2,8,4,2,2,2,4,2,8,4,8,2,2,4,2,2,2,4,2,2,2,2,4,4,8,2,2,2,4,4,2,4,4,2,2,2,2,2,2,8,4,2,4,8,2,2,4,2,4,2,2,2,8,2,2,8,2,2,2,2,2,2,4,2,4,4,4,8,2,2,2,8,2,2,2,2,2,2,2,4,2,2,8,8,2,2,2,2,8,2,4,2,4,4,2,8,2,2,2,2,2,8,2,2,2,4,2,2,2,4,4,2,2,2,8,2,4,4,2,2,8,2,2,2,2,2,2,2,2,4,2,2,2,8,4,2,2,4,2,4,4,8,2,2,4,2,2,2,4,4,4,2,2,4,2,8,2,2,4,2,4,4,2,2,8,2,2,2,8,2,8,2,2,2,2,4,8,2,8,4,4,2,8,2,2,2,4,2,2,2,4,4,2,2,2,2,2,4,2,8,2,4,4,2,2,8,4,2,2,2,2,2,2,2,2,4,2,2,4,2,8,2,2,4,8,4,2,2,2,8,8,2,4,4,4,4,4,4,2,4,2,2,4,2,2,4,8,2,8,2,2,2,2,2,4,2,2,8,2,8,4,2,4,4,2,2,2,4,2,2,2,8,2,8,8,2,2,2,8,2,2,8,2,2,4,2,4,2,8,8,2,8,2,2,4,8,8,8,2,2,2,4,8,2,2,2,2,4,4,2,2,8,2,4,4,4,8,2,2,4,2,4,2,4,2,8,2,2,2,2,2,2,2,2,8,2,2,2,8,2,8,2,2,2,8,8,8,2,8,4,4,2,4,2,2,4,4,8,2,2,4,2,2,8,2,8,2,2,2,4,4,4,2,4,2,8,8,2,2,4,4,2,8,8,2,2,2,8,8,4,4,2,2,4,2,2,4,4,4,2,8,4,2,8,2,2,2,2,4,2,4,4,2,4,4,2,2,2,2,2,2,8,2,2,2,2,2,4,2,4,2,2,2,2,2,2,8,2,8,8,2,8,2,2,2,8,4,2,2,4,8,2,2,8,2,2,4,2,2,2,2,2,4,8,2,2,4,2,4,8,8,4,4,2,2,2,2,4,2,2,2,2,2,2,2,4,2,2,8,2,2,2,2,4,2,4,2,4,4,2,2,2,2,2,2,4,2,2,2,4,2,2,2,2,2,4,2,2,2,2,2,2,4,2,8,2,2,2,8,4,2,2,4,2,2,4,2,2,2,8,2,2,4,4,2,2,2,2,2,2,2,4,2,2,2,4,2,4,2,2,2,4,4,4,2,2,2,2,2,2,4,2,4,4,2,2,2,4,2,2,4,4,4,4,4,2,2,2,2,2];
    uint8[] public techProp = [0,1,4,0,5,2,0,0,0,0,0,3,1,4,0,0,0,0,6,0,3,2,7,3,4,0,1,0,6,4,2,2,7,3,6,6,1,7,5,0,1,0,0,0,3,1,5,1,3,5,4,6,0,1,0,0,2,7,2,0,0,0,0,1,0,1,1,0,0,2,1,0,2,0,3,2,0,0,0,0,0,2,0,1,0,7,1,0,3,0,0,2,3,4,4,0,0,1,0,1,0,0,2,7,0,1,2,1,1,2,0,0,0,0,0,3,1,0,4,3,3,4,1,1,1,1,1,1,0,0,5,1,3,0,0,1,1,2,1,1,0,0,1,3,5,0,1,0,0,2,0,0,0,1,3,0,0,0,7,1,0,0,2,0,0,1,2,0,1,3,0,1,2,2,0,7,2,0,4,2,1,1,1,3,0,1,0,0,0,0,1,0,1,0,0,2,1,2,0,1,0,4,0,0,1,0,0,1,1,0,1,0,5,2,0,4,1,2,0,0,1,1,2,2,0,0,0,0,0,0,1,2,0,1,0,0,0,0,0,0,0,2,0,2,0,0,0,4,2,1,0,0,1,0,1,0,0,0,3,1,0,0,1,3,0,0,0,1,0,2,0,0,3,0,0,0,1,0,0,1,4,1,0,0,0,0,3,0,5,1,0,0,0,1,2,3,1,2,2,0,1,0,0,2,0,1,0,1,1,2,1,0,0,0,1,0,2,2,0,1,2,1,4,3,0,0,0,0,0,3,0,0,0,0,0,0,2,0,1,1,0,0,1,1,3,1,4,1,1,0,1,1,0,0,2,0,0,0,1,0,2,0,0,1,1,1,0,0,2,2,6,0,0,6,2,5,0,0,0,0,1,1,0,2,1,1,0,0,0,3,3,1,1,1,0,2,1,4,0,0,4,0,0,2,1,0,1,0,1,0,2,0,2,1,1,1,2,0,0,0,1,0,0,0,2,0,0,0,1,0,1,4,2,0,0,1,0,3,0,0,0,3,1,1,0,0,0,0,0,0,0,0,1,3,3,1,1,0,0,1,0,0,0,0,1,0,0,4,0,1,0,0,0,1,0,0,1,2,1,1,2,0,0,1,0,0,2,0,1,1,2,1,1,2,1,0,1,1,0,2,0,0,2,0,0,0,2,0,0,0,1,2,1,1,0,1,0,1,0,1,0,4,1,1,0,1,4,6,0,0,2,1,2,2,3,0,1,2,0,2,0,0,0,0,1,2,2,0,1,0,2,0,0,1,2,0,0,1,1,1,0,0,0,0,0,2,0,0,0,0,0,4,2,0,1,0,2,0,0,0,0,2,0,0,0,4,0,0,0,0,1,0,0,0,1,0,1,4,0,0,5,1,1,1,1,0,0,1,0,1,2,0,1,0,0,1,0,0,3,0,0,0,2,0,2,2,3,1,2,0,4,0,0,1,0,0,1,1,0,2,2,2,0,0,1,0,1,0,1,0,1,0,2,1,0,0,3,0,0,1,0,4,1,2,0,2,2,1,1,0,0,0,2,2,1,3,4,0,0,0,0,2,2,0,0,2,0,4,0,1,0,0,1,2,2,0,0,0,0,0,1,0,0,5,0,0,0,0,1,1,1,0,0,0,2,3,1,0,2,3,0,1,0,0,1,1,0,1,1,0,0,0,1,1,3,1,0,1,1,4,0,3,3,1,1,1,2,0,0,2,0,0,1,1,1,1,2,0,0,0,4,5,1,0,0,1,2,0,1,2,0,0,1,0,0,0,0,2,1,0,1,0,1,1,3,2,3,5,5,0,2,1,0,4,2,2,0,0,1,0,0,1,0,0,1,0,0,0,1,0,2,1,0,0,0,1,1,0,2,0,1,2,0,0,1,0,0,0,3,0,1,0,3,0,0,0,0,1,2,2,0,0,0,0,2,0,0,0,1,0,0,0,0,1,1,0,0,0,1,1,1,0,0,1,0,1,2,0,0,3,1,2,1,3,0,0,2,3,2,2,0,0,2,1,0,1,3,0,2,0,3,1,1,1,1,0,0,0,1,2,0,0,0,0,0,0,1,1,0,0,5,0,0,0,1,0,1,0,0,1,1,2,0,0,0,0,3,0,1,0,3,2,0,0,0,1,0,0,1,0,1,0,0,0,0,0,0,2,0,3,0,1,0,0,0,1,2,1,0,0,1,2,0,0,0,0,0,0,1,1,0,3,3,0,0,1,1,1,0,3,2,0,0,0,1,0,0,3,0,0,1,0,0,0,3,1,1,0,1,3,0,0,1,3,0,0,0,0,0,0,0,0,0,0,0,3,3,3,3,0,1,0,5,0];


    constructor(IERC721 _citadelCollection, IERC20 _drakma) {
        citadelCollection = _citadelCollection;
        drakma = _drakma;
        //annexation
        techTree[0] = TechTree(0,7,0,false);
        techTree[1] = TechTree(1,9,0,false);
        techTree[2] = TechTree(2,9,0,false);
        techTree[3] = TechTree(3,7,0,false);
        techTree[4] = TechTree(4,7,0,false);
        techTree[5] = TechTree(5,3,0,false);
        techTree[6] = TechTree(6,6,0,false);
        techTree[7] = TechTree(7,5,0,false);
        //autonomous zone
        techTree[8] = TechTree(0,7,0,false);
        techTree[9] = TechTree(1,9,0,false);
        techTree[10] = TechTree(2,9,0,false);
        techTree[11] = TechTree(3,7,0,false);
        techTree[12] = TechTree(4,7,0,false);
        techTree[13] = TechTree(5,3,0,false);
        techTree[14] = TechTree(6,6,0,false);
        techTree[15] = TechTree(7,5,0,false);
        //sanction
        techTree[16] = TechTree(0,7,0,false);
        techTree[17] = TechTree(1,9,0,false);
        techTree[18] = TechTree(2,9,0,false);
        techTree[19] = TechTree(3,7,0,false);
        techTree[20] = TechTree(4,7,0,false);
        techTree[21] = TechTree(5,3,0,false);
        techTree[22] = TechTree(6,6,0,false);
        techTree[23] = TechTree(7,5,0,false);
        //network state
        techTree[24] = TechTree(0,7,0,false);
        techTree[25] = TechTree(1,9,0,false);
        techTree[26] = TechTree(2,9,0,false);
        techTree[27] = TechTree(3,7,0,false);
        techTree[28] = TechTree(4,7,0,false);
        techTree[29] = TechTree(5,3,0,false);
        techTree[30] = TechTree(6,6,0,false);
        techTree[31] = TechTree(7,5,0,false);
    }

    function stake(uint256[] calldata _tokenIds, uint8 techIndex) external nonReentrant {
        if (stakers[msg.sender].amountStaked > 0) {
            uint256 rewards = calculateRewards(msg.sender);
            stakers[msg.sender].unclaimedRewards += rewards;
            stakers[msg.sender].hasTech = false;
        }

        uint256 runningMultiple = 0;
        for (uint256 i; i < _tokenIds.length; ++i) {
            require(
                citadelCollection.ownerOf(_tokenIds[i]) == msg.sender,
                "Can't stake tokens you don't own!"
            );
            citadelCollection.transferFrom(msg.sender, address(this), _tokenIds[i]);
            uint8 multiple = sektMultiple[_tokenIds[i]];
            uint8 tech = techProp[_tokenIds[i]];
            if(techTree[techIndex].tech == tech) {
                stakers[msg.sender].hasTech = true;
                if(multiple == 16) {
                    techTree[techIndex].hasRelik = true;
                }
            }
            runningMultiple += multiple;
            stakerAddress[_tokenIds[i]] = msg.sender;
        }
        stakers[msg.sender].amountStaked += runningMultiple;
        stakers[msg.sender].timeOfLastUpdate = lastTimeRewardApplicable();
        stakers[msg.sender].techIndex = techIndex;
    }

    function withdraw(uint256[] calldata _tokenIds) external nonReentrant {
        require(
            stakers[msg.sender].amountStaked > 0,
            "You have no tokens staked"
        );
        uint256 rewards = calculateRewards(msg.sender);
        stakers[msg.sender].unclaimedRewards += rewards;

        uint256 runningMultiple = 0;
        for (uint256 i; i < _tokenIds.length; ++i) {
            require(stakerAddress[_tokenIds[i]] == msg.sender);
            stakerAddress[_tokenIds[i]] = address(0);
            citadelCollection.transferFrom(address(this), msg.sender, _tokenIds[i]);
            runningMultiple += sektMultiple[_tokenIds[i]];
        }
        stakers[msg.sender].hasTech = false;
        stakers[msg.sender].amountStaked -= runningMultiple;
        stakers[msg.sender].timeOfLastUpdate = lastTimeRewardApplicable();
    }


    function claimRewards() external nonReentrant {
        uint256 rewards = calculateRewards(msg.sender) +
            stakers[msg.sender].unclaimedRewards;
        require(rewards > 0, "You have no rewards to claim");
        stakers[msg.sender].timeOfLastUpdate = lastTimeRewardApplicable();
        stakers[msg.sender].unclaimedRewards = 0;
        drakma.safeTransfer(msg.sender, rewards);
        
        if(techTree[stakers[msg.sender].techIndex].hasRelik) {
            uint8 techMultiple = stakers[msg.sender].hasTech ? 2 : 1;
            uint256 techRewards = rewards * techMultiple;
            uint256 reseachToComplete = techTree[stakers[msg.sender].techIndex].techLevels * researchPerLevel;
            if (techTree[stakers[msg.sender].techIndex].researchCompleted + techRewards < reseachToComplete) {
                techTree[stakers[msg.sender].techIndex].researchCompleted += techRewards;    
            } else {
                techTree[stakers[msg.sender].techIndex].researchCompleted = reseachToComplete;
            }
        }
    }

    //withdraw leftover DRAKMA when EXORDIUM concludes
    function withdrawDrakma(uint256 amount) external onlyOwner {
        drakma.safeTransfer(msg.sender, amount);
    }
 
    // Views
    function userStakeInfo(address _user)
        public
        view
        returns (uint256 _tokensStaked, uint256 _availableRewards)
    {
        return (stakers[_user].amountStaked, availableRewards(_user));
    }

    function availableRewards(address _user) internal view returns (uint256) {
        uint256 _rewards = stakers[_user].unclaimedRewards +
            calculateRewards(_user);
        return _rewards;
    }

    function getTechTree(uint8 techIndex) public view returns (uint256, bool) {
        return (techTree[techIndex].researchCompleted, techTree[techIndex].hasRelik);
    }

    function getAllTechTree() public view returns (uint256[] memory) {
        uint256[] memory ret = new uint256[](32);
        for (uint i = 0; i < 32; i++) {
            ret[i] = techTree[i].researchCompleted;
        }
        return ret;
    }

    function getCitadelStaker(uint256 tokenId) public view returns (address) {
        return stakerAddress[tokenId];
    }

    function getStaker(address walletAddress) public view returns (uint256, uint256, uint8, bool) {
        return (stakers[walletAddress].amountStaked, stakers[walletAddress].unclaimedRewards, stakers[walletAddress].techIndex, stakers[walletAddress].hasTech);
    }

    function calculateRewards(address _staker)
        internal
        view
        returns (uint256 _rewards)
    {
        return (((
            ((lastTimeRewardApplicable() - stakers[_staker].timeOfLastUpdate) *
                stakers[msg.sender].amountStaked)
        ) * rewardsPerHour) / 3600);
    }

    function lastTimeRewardApplicable() internal view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../../../utils/Address.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/math/SafeMath.sol)

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}