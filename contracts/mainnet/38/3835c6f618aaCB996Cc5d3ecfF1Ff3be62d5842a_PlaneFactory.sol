// File: contracts/PlaneFactory.sol


// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./IPlaneFactory.sol";
import "./IArtData.sol";
import "./Structs.sol";

contract PlaneFactory is IPlaneFactory, Ownable {

    function tokenHash(string memory seed, uint256 planeUid, string memory attName ) internal pure returns (uint256){
        return uint256(keccak256(abi.encodePacked(seed, planeUid, attName)));
    }

    function randomX(string memory seed, uint256 planeInstId, string memory attName, uint maxNum) internal pure returns (uint8) {
        uint256 hash = tokenHash(seed, planeInstId, attName);
        return uint8( hash % maxNum);
    }

    // rawValue is a number from 0 to 99
    function selectByRarity(uint8 rawValue, uint8[] memory rarities) internal pure returns(uint8) {
        uint8 i;
        for(i = 0; i < rarities.length; i++) {
            if(rawValue < rarities[i]) {
                break;
            }
        }
        return i;
    }

    function buildPlane(string memory seed, uint planeInstId, IArtData artData, uint numTrailColors) public view virtual override returns (PlaneAttributes memory){
        PlaneAttributes memory planeAtts;

        planeAtts.locX = randomX(seed, planeInstId, 'locX', artData.getNumOfX());
        planeAtts.locY = randomX(seed, planeInstId, 'locY', artData.getNumOfY());
        planeAtts.angle = randomX(seed, planeInstId, 'angle', artData.getNumAngles());
        planeAtts.trailCol = randomX(seed, planeInstId, 'trailCol', numTrailColors);
        planeAtts.level = selectByRarity(randomX(seed, planeInstId, 'level', 100), artData.getLevelRarities());
        planeAtts.speed = selectByRarity(randomX(seed, planeInstId, 'speed', 100), artData.getSpeedRarities());
        planeAtts.planeType = selectByRarity(randomX(seed, planeInstId, 'planeType', 100), artData.getPlaneTypeRarities());

        return planeAtts;
    }

}

// File: contracts/Structs.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

struct PlaneAttributes {
    uint8 locX;
    uint8 locY;
    uint8 angle;
    uint8 trailCol;
    uint8 level;
    uint8 speed;
    uint8 planeType;
    uint8[] extraParams;
}

struct BaseAttributes {
    uint8 proximity;
    uint8 skyCol;
    uint8 numPlanes;
    uint8 palette;
    PlaneAttributes[] planeAttributes;
    uint8[] extraParams;
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./Structs.sol";
import "./IArtData.sol";

interface IPlaneFactory {
    function buildPlane(string memory seed, uint256 planeInstId, IArtData artData, uint numTrailColors) external view returns (PlaneAttributes memory);
}

// File: contracts/IArtData.sol


// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "./IArtData.sol";

interface IArtData{

    struct ArtProps {
        uint256 numOfX;
        uint256 numOfY;
        uint256 numAngles;
        uint256 numTypes;
        uint256[] extraParams;
    }

    function getProps() external view returns(ArtProps memory);


    function getNumOfX() external view returns (uint) ;

    function getNumOfY() external view returns (uint);

    function getNumAngles() external view returns (uint);

    function getNumTypes() external view returns (uint);

    function getNumSpeeds() external view returns (uint);

    function getSkyName(uint index) external view returns (string calldata);

    function getNumSkyCols() external view returns (uint);

    function getColorPaletteName(uint paletteIdx) external view returns (string calldata) ;

    function getNumColorPalettes() external view returns (uint) ;

    function getPaletteSize(uint paletteIdx) external view returns (uint);

    function getProximityName(uint index) external view returns (string calldata);

    function getNumProximities() external view returns (uint);

    function getMaxNumPlanes() external view returns (uint);


    function getLevelRarities() external view returns (uint8[] calldata);

    function getSpeedRarities() external view returns (uint8[] calldata);

    function getPlaneTypeRarities() external view returns (uint8[] calldata);

    function getProximityRarities() external view returns (uint8[] calldata);

    function getSkyRarities() external view returns (uint8[] calldata) ;

    function getColorPaletteRarities() external view returns (uint8[] calldata) ;

}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }
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