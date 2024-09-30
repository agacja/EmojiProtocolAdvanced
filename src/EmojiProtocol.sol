// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "../lib/solady/src/auth/Ownable.sol";
import {ECDSA} from "../lib/solady/src/utils/ECDSA.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {FixedPointMathLib as FPML} from "../lib/solady/src/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "../lib/solady/src/utils/SafeTransferLib.sol";
import "@pythnetwork/entropy-sdk-solidity/IEntropy.sol";
import "@pythnetwork/entropy-sdk-solidity/IEntropyConsumer.sol";
import {EIP712} from "../lib/solady/src/utils/EIP712.sol";


error NotEthereum();
error NoMoney();
error InsufficientFee();
error FeeTransferFailed();
error NotSpecialToken();
error InsufficientTokenBalance();
error TokenTransferFailed();
error ups();
error fuck();
error RefundFailed();
error IncorrectETHAmount();
error InsufficientSpins();
error not();
error InsufficientNFTs();
error InvalidTelegramId();
error UserNotRegisteredOrInsufficientPayment();
error TokenAlreadySpecial();
error dupa();

interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

interface ICrossDomainMessenger {
    function xDomainMessageSender() external view returns (address);
    function sendMessage(address _target, bytes calldata _message, uint32 _gasLimit) external payable;
}

interface IWETH {
    function deposit() external payable;
    function withdraw(uint256) external;
    function approve(address, uint256) external returns (bool);
}

interface IChip {

     struct TokenData {
        address uri;
        uint96 price;
    }

    function mintFromEmojiProtocol(address to, uint256 quantity, uint256 tokenId) external;
    function burn(address from, uint256 tokenId, uint256 quantity) external;
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function withdraw(uint96 money) external;
    function getOwnerTokens(address owner) external view returns (uint256);
    function getPrice(uint256 tokenId) external view returns (uint96);
    
}

contract EmojiProtocol is Ownable, IEntropyConsumer, EIP712 {
    using ECDSA for bytes32;
    
    ICrossDomainMessenger public MESSENGER;
    uint32 public bridgeGasLimit = 2000000;
    address public signer;

    ISwapRouter public swapRouter;
    IERC20 public MOG_COIN;
    IWETH public WETH;
    uint256 public PLATFORM_FEE = 1e15; // 0.001 native token
    uint256 public BETTER_PLATFORM_FEE = 1e20;
    uint256 public constant ERC20_FEE_DISCOUNT = 50;
    uint256 public SPIN_PRICE;
    uint256 public price;

    address[] public specialTokens;

    IEntropy private entropy;
    address private entropyProvider;

    event SpinRequest(uint64 sequenceNumber, address spinner);
    event SpinResult(uint64 sequenceNumber, uint8 slot1, uint8 slot2, uint8 slot3);

    mapping(uint64 => address) public spinToSpinner;

    mapping(address => address) public DiscountTokens;
    mapping(bytes32 => address) public Spins;

    bytes32 private constant REGISTER_TYPEHASH = 
        keccak256("Info(string telegramId,address walletAddress)");

    mapping(address => string) public registeredUsers;
    mapping(string => address) public userAddresses; // New mapping to get address from telegramId

    struct Info {
        string telegramId;
        address walletAddress;
    }

    IChip public chip;


    constructor(address _entropy, address _entropyProvider) {
        _initializeOwner(0x644C1564d1d19Cf336417734170F21B944109074);
        MESSENGER = ICrossDomainMessenger(0x866E82a600A1414e583f7F13623F1aC5d58b0Afa);
        entropy = IEntropy(_entropy);
        entropyProvider = _entropyProvider;
    }

    function _domainNameAndVersion() internal pure override returns (string memory name, string memory version) {
        name = "EmojiProtocol";
        version = "1";
    }

    function _domainNameAndVersionMayChange() internal pure override returns (bool) {
        return false;
    }

    modifier requireSignature(bytes calldata signature) {
        require(
            keccak256(abi.encode(msg.sender)).toEthSignedMessageHash().recover(signature) == signer,
            "Invalid signature."
        );
        _;
    }

    function initialize(address _swapRouter, address _mogCoin, address _weth) external onlyOwner {
        swapRouter = ISwapRouter(_swapRouter);
        //add bret, and other major coins
        MOG_COIN = IERC20(_mogCoin);
        WETH = IWETH(_weth);
    }
//setting it here in case of some problems
    function setChipAddress(address _chipAddress) external onlyOwner {
        chip = IChip(_chipAddress);
    }

    function setBridgeGasLimit(uint32 _newGasLimit) external onlyOwner {
        bridgeGasLimit = _newGasLimit;
    }

    function bridgeAndSwapFromEthereum() public payable {
        if (block.chainid != 1) revert NotEthereum();
        MESSENGER.sendMessage{value: msg.value}(
            address(this),
            abi.encodeCall(this.bridgeAndSwapOnBase, (address(this))),
            bridgeGasLimit
        );
    }

    function bridgeAndSwapOnBase(address recipient) external payable {
        uint256 amountIn = address(this).balance;
        if (amountIn == 0) revert NoMoney();
        _wrapAndSwap(recipient, amountIn);
    }

function _wrapAndSwap(address recipient, uint256 amountIn) internal {
    
    WETH.deposit{value: amountIn}();
    SafeTransferLib.safeApprove(address(WETH), address(swapRouter), amountIn);

    uint256 amountPerToken = amountIn / specialTokens.length;

    for (uint256 i = 0; i < specialTokens.length; i++) {
        swapRouter.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(WETH),
                tokenOut: specialTokens[i],
                fee: 3000,
                recipient: recipient,
                amountIn: amountPerToken,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );
    }
}

    function register(Info calldata info, bytes calldata signature) external {
        if (info.walletAddress != msg.sender) revert dupa();
        bytes32 structHash = keccak256(abi.encode(
            REGISTER_TYPEHASH,
            keccak256(bytes(info.telegramId)),
            info.walletAddress
        ));

        bytes32 hash = _hashTypedData(structHash);

        address recoveredSigner = ECDSA.recover(hash, signature);

        if (recoveredSigner != signer) revert fuck();

        registeredUsers[info.walletAddress] = info.telegramId;
        userAddresses[info.telegramId] = info.walletAddress;
    }

    function buySpins(uint256 amount, uint256 tokenId) external payable {
        if (msg.value != price * amount || bytes(registeredUsers[msg.sender]).length == 0) {
            revert UserNotRegisteredOrInsufficientPayment();
        }
      
        chip.mintFromEmojiProtocol(msg.sender, amount,tokenId);

    }


    

   function requestSpin(bytes32 userRandomNumber, string calldata telegramId) external payable onlyOwner {
        address spinner = userAddresses[telegramId];

        if (spinner == address(0)) revert InvalidTelegramId();
        if (bytes(registeredUsers[spinner]).length == 0) revert InvalidTelegramId();

        uint256 fee = entropy.getFee(entropyProvider);
        if (msg.value < fee) revert InsufficientFee();
        
     
        uint64 sequenceNumber = entropy.requestWithCallback{value: fee}(
            entropyProvider,
            userRandomNumber
        );
        
    
        emit SpinRequest(sequenceNumber, spinner);
        spinToSpinner[sequenceNumber] = spinner;
    }

    function getSpinFee() public view returns (uint256) {
        return entropy.getFee(entropyProvider);
    }

    function entropyCallback(
        uint64 sequenceNumber,
        address,
        bytes32 randomNumber
    ) internal override {
        uint256 randomValue = uint256(randomNumber);
        uint8 slot1 = uint8(randomValue % 4);
        uint8 slot2 = uint8((randomValue >> 2) % 4);
        uint8 slot3 = uint8((randomValue >> 4) % 4);
        uint8 hugoCheck = uint8((randomValue >> 6) % 10);

        address spinner = spinToSpinner[sequenceNumber];
        uint256 lowestTokenId = chip.getOwnerTokens(spinner);
        uint96 money = chip.getPrice(lowestTokenId);
        chip.burn(spinner,lowestTokenId, 1);
        chip.withdraw(money);

        
        if (slot1 == slot2 && slot2 == slot3) {
            if (slot1 == 0 && hugoCheck == 0) {
                _processWin(spinner, 10000); // Hugo win
            } else if (slot1 <= 2) {
                _processWin(spinner, 2000); // Grape win
            } else if (slot1 <= 4) {
                _processWin(spinner, 4000); // Bar win
            } else {
                _processWin(spinner, 3000); // Lemon win
            }
        }

        delete spinToSpinner[sequenceNumber];

        emit SpinResult(sequenceNumber, slot1, slot2, slot3);
    }

    function _processWin(address recipient, uint256 winPercentage) internal {
        uint256 length = specialTokens.length;
        
        for (uint256 i; i < length;) {
            address token = specialTokens[i];
            uint256 balance = IERC20(token).balanceOf(address(this));
            uint256 winAmount = (balance * winPercentage) / 10000;
            uint256 feeAmount = (winAmount * 500) / 10000; // 5% fee
            uint256 recipientAmount = winAmount - feeAmount;

            if (recipientAmount > 0) {
                SafeTransferLib.safeTransfer(token, recipient, recipientAmount);
            }
            if (feeAmount > 0) {
                SafeTransferLib.safeTransfer(token, owner(), feeAmount);
            }

            unchecked { ++i; }
        }
    }

    function getEntropy() internal view override returns (address) {
        return address(entropy);
    }

    function addSpecialTokens(address speciality) external payable onlyOwner {
        uint256 length = specialTokens.length;
        for (uint256 i; i < length;) {
            if (specialTokens[i] == speciality) revert TokenAlreadySpecial();
            unchecked { ++i; }
        }
        specialTokens.push(speciality);
    }

    function setSigner(address value) external onlyOwner {
        signer = value;
    }

    function setSpinPrice(uint256 _price) external onlyOwner {
        if (_price > 1e15) revert not();
        SPIN_PRICE = _price;
    }

    receive() external payable {
        if (block.chainid == 1) {
            bridgeAndSwapFromEthereum();
        } else if (block.chainid == 8453) {
            _wrapAndSwap(address(this), msg.value);
        }
    }
}