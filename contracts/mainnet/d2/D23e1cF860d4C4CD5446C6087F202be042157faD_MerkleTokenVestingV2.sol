// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import {TokenVesting} from "./TokenVesting.sol";
import {MerkleDistributor} from "./MerkleDistributor.sol";

contract MerkleTokenVestingV2 is TokenVesting, MerkleDistributor {
  event Claimed(uint256 index, address account, uint256 amount, bool revocable);

  /**
   * @dev Creates a vesting contract that vests its balance of any ERC20 token to beneficiaries gradually in a linear fashion until _start + _duration. By then all
   * of the balance will have vested.
   * @param start start block to begin vesting
   * @param cliff cliff to start vesting on, set to zero if immediately after start
   * @param duration duration in blocks to vest over
   */
  function initialize(
    uint256 start,
    uint256 cliff,
    uint256 duration,
    address token,
    bytes32 _merkleRoot
  ) public initializer {
    __TokenVesting_init(start, cliff, duration, token);
    __MerkleDistributor_init(_merkleRoot);
  }

  function claimAward(
    uint256 index,
    address account,
    uint256 amount,
    bool revocable,
    bytes32[] calldata merkleProof
  ) external {
    require(!isClaimed(index), "Award already claimed");

    // Verify the merkle proof.
    bytes32 node =
      keccak256(abi.encodePacked(index, account, amount, revocable));
    _verifyClaim(merkleProof, node);

    _setClaimed(index);

    _awardTokens(account, amount, revocable);

    emit Claimed(index, account, amount, revocable);
  }

  // Function to award tokens to an account if it was missed in the merkle tree
  function awardTokens(
    address account,
    uint256 amount,
    bool revocable
  ) external onlyOwner {
    _awardTokens(account, amount, revocable);
  }

  function empty() external onlyOwner {
    targetToken.transfer(owner(), targetToken.balanceOf(address(this)));
  }

  function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
    require(_merkleRoot != merkleRoot, "Same root");
    merkleRoot = _merkleRoot;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title TokenVesting
 * @dev This contract is used to award vesting tokens to wallets.
 * Multiple wallets can be vested to using this contract, all using the same vesting schedule.
 */
abstract contract TokenVesting is OwnableUpgradeable {
  /*
   * Emitted when vesting tokens are rewarded to a beneficiary
   */
  event Awarded(address indexed beneficiary, uint256 amount, bool revocable);

  /**
   * Emitted when vesting tokens are released to a beneficiary
   */
  event Released(address indexed beneficiary, uint256 amount);

  /**
   * Emitted when vesting tokens are revoked from a beneficiary
   */
  event Revoked(address indexed beneficiary, uint256 revokedAmount);

  // Global vesting parameters for this contract
  uint256 public vestingStart;
  uint256 public vestingCliff;
  uint256 public vestingDuration;

  struct TokenAward {
    uint256 amount;
    uint256 released;
    bool revocable;
    bool revoked;
  }

  // Tracks the token awards for each user (user => award)
  mapping(address => TokenAward) public awards;

  IERC20Upgradeable public targetToken;

  function __TokenVesting_init(
    uint256 start,
    uint256 cliff,
    uint256 duration,
    address token
  ) internal initializer {
    __Ownable_init();

    require(cliff <= duration, "Cliff must be less than duration");

    vestingStart = start;
    vestingCliff = start + cliff;
    vestingDuration = duration;
    targetToken = IERC20Upgradeable(token);
  }

  function setVestingParams(
    uint256 start,
    uint256 cliffBlock,
    uint256 duration
  ) external onlyOwner {
    require(
      start != vestingStart ||
        cliffBlock != vestingCliff ||
        vestingDuration != duration,
      "no state change"
    );

    vestingStart = start;
    vestingCliff = cliffBlock;
    vestingDuration = duration;
  }

  /**
   * @notice Transfers vested tokens to beneficiary.
   * @param beneficiary Who the tokens are being released to
   */
  function release(address beneficiary) public {
    uint256 unreleased = getReleasableAmount(beneficiary);
    require(unreleased > 0, "Nothing to release");

    TokenAward storage award = getTokenAwardStorage(beneficiary);
    award.released += unreleased;

    targetToken.transfer(beneficiary, unreleased);

    emit Released(beneficiary, unreleased);
  }

  /**
   * @notice Allows the owner to revoke the vesting. Tokens already vested
   * are transfered to the beneficiary, the rest are returned to the owner.
   * @param beneficiary Who the tokens are being released to
   */
  function revoke(address beneficiary) public onlyOwner {
    TokenAward storage award = getTokenAwardStorage(beneficiary);

    require(award.revocable, "Cannot be revoked");
    require(!award.revoked, "Already revoked");

    // Figure out how many tokens were owed up until revocation
    uint256 unreleased = getReleasableAmount(beneficiary);
    award.released += unreleased;

    uint256 refund = award.amount - award.released;

    // Mark award as revoked
    award.revoked = true;
    award.amount = award.released;

    // Transfer owed vested tokens to beneficiary
    targetToken.transfer(beneficiary, unreleased);
    // Transfer unvested tokens to owner (revoked amount)
    targetToken.transfer(owner(), refund);

    emit Released(beneficiary, unreleased);
    emit Revoked(beneficiary, refund);
  }

  /**
   * @dev Calculates the amount that has already vested but hasn't been released yet.
   * @param beneficiary Who the tokens are being released to
   */
  function getReleasableAmount(address beneficiary)
    public
    view
    returns (uint256)
  {
    TokenAward memory award = getTokenAward(beneficiary);

    return getVestedAmount(beneficiary) - award.released;
  }

  /**
   * @dev Calculates the amount that has already vested.
   * @param beneficiary Who the tokens are being released to
   */
  function getVestedAmount(address beneficiary) public view returns (uint256) {
    TokenAward memory award = getTokenAward(beneficiary);

    if (block.number < vestingCliff) {
      return 0;
    } else if (
      block.number >= vestingStart + vestingDuration || award.revoked
    ) {
      return award.amount;
    } else {
      return (award.amount * (block.number - vestingStart)) / vestingDuration;
    }
  }

  function _awardTokens(
    address beneficiary,
    uint256 amount,
    bool revocable
  ) internal {
    TokenAward storage award = getTokenAwardStorage(beneficiary);
    require(award.amount == 0, "Cannot award twice");

    award.amount = amount;
    award.revocable = revocable;

    emit Awarded(beneficiary, amount, revocable);
  }

  function getTokenAward(address beneficiary)
    internal
    view
    returns (TokenAward memory)
  {
    TokenAward memory award = awards[beneficiary];
    return award;
  }

  function getTokenAwardStorage(address beneficiary)
    internal
    view
    returns (TokenAward storage)
  {
    TokenAward storage award = awards[beneficiary];
    return award;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";

abstract contract MerkleDistributor {
  bytes32 public merkleRoot;

  // This is a packed array of booleans.
  mapping(uint256 => uint256) private claimedBitMap;

  function __MerkleDistributor_init(bytes32 _merkleRoot) internal {
    merkleRoot = _merkleRoot;
  }

  /**
   * @dev Used to check if a merkle claim has been claimed from the merkle tree.
   * @param index The index of the award
   */
  function isClaimed(uint256 index) public view returns (bool) {
    uint256 claimedWordIndex = index / 256;
    uint256 claimedBitIndex = index % 256;
    uint256 claimedWord = claimedBitMap[claimedWordIndex];
    uint256 mask = (1 << claimedBitIndex);
    return claimedWord & mask == mask;
  }

  /**
   * @dev Used to set that a merkle claim has been claimed.
   * @param index The index of the award
   */
  function _setClaimed(uint256 index) internal {
    uint256 claimedWordIndex = index / 256;
    uint256 claimedBitIndex = index % 256;
    claimedBitMap[claimedWordIndex] =
      claimedBitMap[claimedWordIndex] |
      (1 << claimedBitIndex);
  }

  function _verifyClaim(bytes32[] calldata merkleProof, bytes32 node)
    internal
    view
  {
    require(
      MerkleProofUpgradeable.verify(merkleProof, merkleRoot, node),
      "MerkleDistributor: Invalid proof"
    );
  }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

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

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";
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
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init() internal initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal initializer {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
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
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal initializer {
        __Context_init_unchained();
    }

    function __Context_init_unchained() internal initializer {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT

// solhint-disable-next-line compiler-version
pragma solidity ^0.8.0;

import "../../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since a proxied contract can't have a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {UpgradeableProxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 */
abstract contract Initializable {

    /**
     * @dev Indicates that the contract has been initialized.
     */
    bool private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Modifier to protect an initializer function from being invoked twice.
     */
    modifier initializer() {
        require(_initializing || !_initialized, "Initializable: contract is already initialized");

        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
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
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
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

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
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
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
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
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
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

pragma solidity ^0.8.0;

/**
 * @dev These functions deal with verification of Merkle trees (hash trees),
 */
library MerkleProofUpgradeable {
    /**
     * @dev Returns true if a `leaf` can be proved to be a part of a Merkle tree
     * defined by `root`. For this, a `proof` must be provided, containing
     * sibling hashes on the branch from the leaf to the root of the tree. Each
     * pair of leaves and each pair of pre-images are assumed to be sorted.
     */
    function verify(bytes32[] memory proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];

            if (computedHash <= proofElement) {
                // Hash(current computed hash + current element of the proof)
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                // Hash(current element of the proof + current computed hash)
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }

        // Check if the computed hash (root) is equal to the provided root
        return computedHash == root;
    }
}