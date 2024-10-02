// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC1155} from "../lib/solady/src/tokens/ERC1155.sol";
import {Ownable} from "../lib/solady/src/auth/Ownable.sol";
import {SafeTransferLib} from "../lib/solady/src/utils/SafeTransferLib.sol";
import {LibString} from "../lib/solady/src/utils/LibString.sol";
import {FixedPointMathLib as FPML} from "../lib/solady/src/utils/FixedPointMathLib.sol";
import {SSTORE2} from "../lib/solady/src/utils/SSTORE2.sol";
import {EnumerableSetLib} from "../lib/solady/src/utils/EnumerableSetLib.sol";

error SaleClosed();
error InvalidTokenId();
error NotAllowed();
error BaseURILocked();
error InsufficientPayment();
error Exists();
error DoesntExist();
error noTokens();


contract Chip is ERC1155, Ownable {
    using EnumerableSetLib for EnumerableSetLib.Uint256Set;
    using SafeTransferLib for address payable;
    using LibString for uint256;

    struct TokenData {
        address uri;
        uint96 price;
    }

    uint8 public saleState;
    uint16 public spinFee;
    bool public baseURILocked;
    EnumerableSetLib.Uint256Set private _tokenIds;

    address private _baseURI;
    address public emojiProtocolAddress;

    mapping(uint256 => TokenData) public tokenData;
    mapping(address => EnumerableSetLib.Uint256Set) private _ownerTokenIds;

    event TokenCreated(uint256 indexed tokenId, uint96 price);
    event TokenURIUpdated(uint256 indexed tokenId, string newUri);
    event BaseURIUpdated(string newBaseURI);



    constructor() ERC1155() {
        _initializeOwner(msg.sender);
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        if (!_tokenIds.contains(tokenId)) revert DoesntExist();
        address tokenURI = tokenData[tokenId].uri;
        if (tokenURI == address(0)) {
            return string(abi.encodePacked(SSTORE2.read(_baseURI), tokenId.toString()));
        } else {
            return string(SSTORE2.read(tokenURI));
        }
    }

    function setEmojiProtocolAddress(address _emojiProtocolAddress) external onlyOwner {
        emojiProtocolAddress = _emojiProtocolAddress;
    }

    function mintFromEmojiProtocol(address to, uint256 tokenId, uint256 quantity) external payable  {
        if (msg.sender != emojiProtocolAddress) revert NotAllowed();
        if (saleState == 0) revert SaleClosed();
        if (!_tokenIds.contains(tokenId)) revert InvalidTokenId();
        uint256 totalPrice = FPML.fullMulDiv(quantity, tokenData[tokenId].price, 1);
        uint256 spinFeeAmount = FPML.fullMulDiv(totalPrice, spinFee, 10000);
        if (msg.value < totalPrice) revert InsufficientPayment();
        payable(emojiProtocolAddress).safeTransferETH(spinFeeAmount);
        _mint(to, tokenId, quantity, "");
        _ownerTokenIds[to].add(tokenId);
    }

    function burn(address from, uint256 tokenId, uint256 quantity) external {
        if (msg.sender != emojiProtocolAddress) revert NotAllowed();
        _burn(from, tokenId, quantity);
        if (balanceOf(from, tokenId) == 0) {
            _ownerTokenIds[from].remove(tokenId);
        }
    }

    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        if (baseURILocked) revert BaseURILocked();
        _baseURI = SSTORE2.write(bytes(newBaseURI));
        emit BaseURIUpdated(newBaseURI);
    }

    function lockBaseURI() external onlyOwner {
        baseURILocked = true;
    }

    function setSaleState(uint8 value) external onlyOwner {
        saleState = value;
    }
   

    function createToken(uint256 tokenId, string memory tokenURI, uint96 price) external onlyOwner {
        if (_tokenIds.contains(tokenId)) revert Exists();
        address metadata = bytes(tokenURI).length > 0 ? SSTORE2.write(bytes(tokenURI)) : address(0);

        tokenData[tokenId] = TokenData({
            uri: metadata,
            price: price
        });
        _tokenIds.add(tokenId);
        emit TokenCreated(tokenId, price);
    }

    function updateTokenURI(uint256 tokenId, string memory newTokenURI) external onlyOwner {
        if (!_tokenIds.contains(tokenId)) revert DoesntExist();
        tokenData[tokenId].uri = SSTORE2.write(bytes(newTokenURI));
        emit TokenURIUpdated(tokenId, newTokenURI);
    }

    function updateTokenPrice(uint256 tokenId, uint96 newPrice) external onlyOwner {
        if (!_tokenIds.contains(tokenId)) revert DoesntExist();
        tokenData[tokenId].price = newPrice;
    }

    function getTokenIds() external view returns (uint256[] memory) {
        return _tokenIds.values();
    }

    function getPrice(uint256 tokenId) external view returns (uint96) {
        return tokenData[tokenId].price;
    }

   function setSpinFee(uint16 fee) external onlyOwner{
        spinFee = fee;
    }



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

    function withdraw(uint96 money) external {
        if (msg.sender != emojiProtocolAddress) revert NotAllowed();
        SafeTransferLib.safeTransferETH(payable(emojiProtocolAddress), money);
    }
}