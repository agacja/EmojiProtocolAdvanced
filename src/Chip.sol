// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


error SaleClosed();
error InvalidTokenId();
error NotAllowed();
error BaseURILocked();
error InsufficientPayment();
error Exists();
error DoesntExist();
error noTokens();

import {ERC1155} from "../lib/solady/src/tokens/ERC1155.sol";
import {Ownable} from "../lib/solady/src/auth/Ownable.sol";
import {SafeTransferLib} from "../lib/solady/src/utils/SafeTransferLib.sol";
import {LibString} from "../lib/solady/src/utils/LibString.sol";
import {FixedPointMathLib as FPML} from "../lib/solady/src/utils/FixedPointMathLib.sol";
import {SSTORE2} from "../lib/solady/src/utils/SSTORE2.sol";
import {EnumerableSetLib} from "../lib/solady/src/utils/EnumerableSetLib.sol";
import "./jajca.sol";


contract Chip is ERC1155, Ownable {

    // ============ Library Usage ============
    using EnumerableSetLib for EnumerableSetLib.Uint256Set;
    using SafeTransferLib for address payable;
    using LibString for uint256;
    using jajca for function(uint256) internal view returns (uint256);
    using jajca for function(uint256) internal view returns (TokenData memory);

    // ============ State Variables ============
    TokenData internal _data;
    uint8 public saleState;
    uint16 public spinFee;
    bool public baseURILocked;
    EnumerableSetLib.Uint256Set private _tokenIds;
    address private _baseURI;
    address public emojiProtocolAddress;

    // ============ Mappings ============
    mapping(uint256 => TokenData) internal tokenData;
    mapping(address => EnumerableSetLib.Uint256Set) private _ownerTokenIds;

    // ============ Events ============
    event TokenCreated(uint256 indexed tokenId, uint96 price);
    event TokenURIUpdated(uint256 indexed tokenId, string newUri);
    event BaseURIUpdated(string newBaseURI);

    // ============ Constructor ============
    constructor() ERC1155() {
        _initializeOwner(msg.sender);
    }

    // ============ URI Functions ============
    function uri(uint256 tokenId) public view override returns (string memory) {
        if (!_tokenIds.contains(tokenId)) revert DoesntExist();
        string memory tokenURI = tokenData[tokenId].uri;
        if (bytes(tokenURI).length == 0) {
            return string(abi.encodePacked(SSTORE2.read(_baseURI), tokenId.toString()));
        } else {
            return tokenURI;
        }
    }

    // ============ Admin Functions ============
    function setEmojiProtocolAddress(address _emojiProtocolAddress) external onlyOwner {
        emojiProtocolAddress = _emojiProtocolAddress;
    }

    // ============ Minting Functions ============
    function mintFromEmojiProtocol(
        address to,
        uint256 tokenId,
        uint256 quantity,
        address feeRecipient
    ) external payable {
        if (msg.sender != emojiProtocolAddress) revert NotAllowed();
        if (saleState == 0) revert SaleClosed();
        if (!_tokenIds.contains(tokenId)) revert InvalidTokenId();
      
        uint256 totalPrice = FPML.fullMulDiv(
            quantity,
            tokenData[tokenId].price,
            1
        );
        uint256 spinFeeAmount = FPML.fullMulDiv(totalPrice, spinFee, 10000);
        if (msg.value < totalPrice) revert InsufficientPayment();
        payable(feeRecipient).safeTransferETH(spinFeeAmount);

        //assembly 
        assembly{
            mstore(0x00, 0x731133e9)
            mstore(0x04,to)
            mstore(0x24,tokenId)
            mstore(0x44, quantity)
               // Execute the transfer and mint
                if iszero(call(gas(), chip, 0, 0x00, 0x64, 0, 0)) { revert(0, 0) }
            }
    }
        //_mint(to, tokenId, quantity, "");
    mstore(0x00, to)
    mstore(0x20, _ownerTokenIds.slot)
   let setSlot := keccak256(0x00, 0x40)

 
   let length := sload(setSlot)

   // Store value in array
   mstore(0x00, setSlot)
   let arrayLocation := keccak256(0x00, 0x40)
   sstore(add(arrayLocation, length), tokenId)

   // Update positions mapping
   mstore(0x00, tokenId)
   mstore(0x20, add(setSlot, 1))
   sstore(keccak256(0x00, 0x40), add(length, 1))

   // Update length
   sstore(setSlot, add(length, 1))
}
       // _ownerTokenIds[to].add(tokenId);
    }

    // ============ Burn Functions ============
    function burn(address from, uint256 tokenId, uint256 quantity) external {
        if (msg.sender != emojiProtocolAddress) revert NotAllowed();
        _burn(from, tokenId, quantity);
        if (balanceOf(from, tokenId) == 0) {
            _ownerTokenIds[from].remove(tokenId);
        }
    }

    // ============ URI Management Functions ============
    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        if (baseURILocked) revert BaseURILocked();
        _baseURI = SSTORE2.write(bytes(newBaseURI));
        emit BaseURIUpdated(newBaseURI);
    }

    function lockBaseURI() external onlyOwner {
        baseURILocked = true;
    }

    // ============ Sale Management Functions ============
    function setSaleState(uint8 value) external onlyOwner {
        saleState = value;
    }

    // ============ Token Management Functions ============
    function createToken(uint256 tokenId, string memory urio, uint96 price) external onlyOwner {
        if (_tokenIds.contains(tokenId)) revert Exists();
        address uriAddress;
        if (bytes(urio).length > 0) {
            uriAddress = SSTORE2.write(bytes(urio));
        }

        assembly {
            // Calculate the storage slot for this tokenId in the mapping
            mstore(0x00, tokenId)
            mstore(0x20, tokenData.slot)
            let baseSlot := keccak256(0x00, 0x40)

            // Slot 0 Storage Layout:
            // [0:96] | price (96 bits)
            // [96:255] | uriAddress (160 bits for address of SSTORE2 pointer)
            // [255:256] | isOpen (1 bit)
            let slot0 := or(
                or(price, shl(96, uriAddress)),
                shl(255, 1) // isOpen is always true when creating
            )
            sstore(baseSlot, slot0)
        }
        _tokenIds.add(tokenId);
        emit TokenCreated(tokenId, price);
    }

    function updateTokenPrice(uint256 tokenId, uint96 newPrice) external onlyOwner {
        if (!_tokenIds.contains(tokenId)) revert DoesntExist();
        tokenData[tokenId].price = newPrice;
    }

    // ============ View Functions ============
    function getTokenIds() external view returns (uint256[] memory) {
        return _tokenIds.values();
    }

    function getspinFee() external view returns (uint16) {
        return spinFee;
    }

    function getPrice(uint256 tokenId) external view returns (uint96) {
        return tokenData[tokenId].price;
    }

    // ============ Fee Management Functions ============
    function setSpinFee(uint16 fee) external onlyOwner {
        spinFee = fee;
    }

    // ============ Internal Data Functions ============
    function _calculateCurrentDataPointers(uint256 tokenId) internal view returns (uint256 data) {
        data = _calculateCurrentData.asReturnsPointers()(tokenId);
    }

    function Price(uint256 tokenId) external view returns (uint256) {
        return _calculateCurrentDataPointers.asReturnsTokenData()(tokenId).price;
    }

    function _calculateCurrentData(uint256 tokenId) internal view returns (TokenData memory) {
        return tokenData[tokenId];
    }

    // ============ Owner Token Functions ============
    function getOwnerTokens(address owner) external view returns (uint256) {
        uint256[] memory tokens = _ownerTokenIds[owner].values();
        
        if(tokens.length == 0) revert noTokens();
        
        uint256 lowestTokenId = tokens[0];
        for (uint256 i = 1; i < tokens.length; i++) { 
            if (tokens[i] < lowestTokenId) {
                lowestTokenId = tokens[i];
            }
        }
        
        return lowestTokenId;
    }

    function getLowestTokenPriceForOwner(address owner) external view returns (uint256 lowestTokenId, uint256 price) {
        uint256[] memory tokens = _ownerTokenIds[owner].values();
        
        if(tokens.length == 0) revert noTokens();
        
        lowestTokenId = tokens[0];
        for (uint256 i = 1; i < tokens.length; i++) { 
            if (tokens[i] < lowestTokenId) {
                lowestTokenId = tokens[i];
            }
        }
        
        price = this.Price(lowestTokenId);
    }

    // ============ Withdrawal Functions ============
    function withdraw(uint96 money) external {
        if (msg.sender != emojiProtocolAddress) revert NotAllowed();
        SafeTransferLib.safeTransferETH(payable(emojiProtocolAddress), money);
    }
}