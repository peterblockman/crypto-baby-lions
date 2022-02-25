// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '@openzeppelin/contracts/interfaces/IERC20.sol';
import '@openzeppelin/contracts/interfaces/IERC165.sol';
import '@openzeppelin/contracts/interfaces/IERC2981.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/cryptography/MerkleProof.sol';


contract CryptoBabyLions is Ownable, ERC721('Crypto Baby Lions', 'CBL'), IERC2981 {
    using Strings for uint256;
    using Counters for Counters.Counter;

    struct WhitelistInfo {
        bytes32 merkleRoot;
        uint256 quantity;
        uint256 price;
    }

    uint16 internal royalty = 500; // base 10000, 5%
    uint16 public constant MAX_PRE_MINT = 500;
    uint16 public constant BASE = 10000;
    uint16 public constant MAX_TOKENS = 8898;
    uint16 public constant MAX_MINT = 3;
    uint256 public constant MINT_PRICE = 0.05 ether;
    uint256 public startBlock = type(uint256).max - 1;

    string private baseURI;
    string private centralizedURI;
    string private contractMetadata;
    address public withdrawAccount;
    Counters.Counter private _tokenIds;
    Counters.Counter private _preMintTokenIds;
    Counters.Counter private whitelistPlansCounter;
    mapping(uint256 => WhitelistInfo) public whitelistPlans;
    mapping(address => uint256) public mintedCount;

    modifier onlyWhitdrawable() {
        require(_msgSender() == withdrawAccount, 'CBL: Not authorzed to withdraw');
        _;
    }

    constructor(string memory _contractMetadata, string memory ipfsURI, string memory _centralizedURI) {
        contractMetadata = _contractMetadata;
        baseURI = ipfsURI;
        centralizedURI = _centralizedURI;
        whitelistPlansCounter.increment(); // index 0 is reserved for public so start from 1
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, IERC165) returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), 'CBL: URI query for nonexistent token');

        string memory baseContractURI = _baseURI();
        if (totalSupply() < MAX_TOKENS) {
            baseContractURI =  centralizedURI;
        }

        return string(abi.encodePacked(baseContractURI, tokenId.toString()));
    }

    function contractURI() public view returns (string memory) {
        return contractMetadata;
    }

    function totalSupply() public view returns (uint256) {
        return _tokenIds.current();
    }

    function totalPreMinted() public view returns (uint256) {
        return _preMintTokenIds.current();
    }

    function royaltyInfo(uint256, uint256 _salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        return (address(this), (_salePrice * royalty) / BASE);
    }

    function freeMint() public {
        address msgSender = _msgSender();
        require(_tokenIds.current() < MAX_TOKENS, 'CBL: That many tokens are not available');
        require(_preMintTokenIds.current() < MAX_PRE_MINT, 'CBL: No more tokens to pre-mint');
        require(mintedCount[msgSender] == 0, 'CBL: You can only pre-mint once');

        mintedCount[msgSender] = 1;
        _safeMint(msgSender, _tokenIds.current());
        _preMintTokenIds.increment();
        _tokenIds.increment();
    }

    function whitelistMint(uint256 quantity, uint whitelistIndex, bytes32[] calldata proof) public payable {
        require(_tokenIds.current() + quantity <= MAX_TOKENS, 'CBL: That many tokens are not available');
        address msgSender = _msgSender();
        uint256 accountNewMintCount = mintedCount[msgSender] + quantity;

        WhitelistInfo memory whitelistInfo = whitelistPlans[whitelistIndex];

        require(accountNewMintCount <= whitelistInfo.quantity, 'CBL: That many tokens are not available this account');

        bytes32 leaf = keccak256(abi.encodePacked(msgSender));
        require(MerkleProof.verify(proof, whitelistInfo.merkleRoot, leaf), 'CBL: Invalid proof');

        uint256 totalPrice = quantity * whitelistInfo.price;
        require(msg.value >= totalPrice, 'CBL: Need to send more ethers');
        if (msg.value > totalPrice) {
            payable(msgSender).transfer(msg.value - totalPrice);
        }

        mintedCount[msgSender] = accountNewMintCount;
        for (uint256 i = 0; i < quantity; i++) {
            _safeMint(msgSender, _tokenIds.current());
            _tokenIds.increment();
        }
    }
    function mint(uint256 quantity) public payable {
        require(startBlock <= block.number, 'CBL: Minting time is not started');
        require(_tokenIds.current() + quantity <= MAX_TOKENS, 'CBL: That many tokens are not available');
        address msgSender = _msgSender();
        uint256 accountNewMintCount = mintedCount[msgSender] + quantity;

        require(accountNewMintCount <= MAX_MINT, 'CBL: That many tokens are not available this account');

        uint256 totalPrice = quantity * MINT_PRICE;
        require(msg.value >= totalPrice, 'CBL: Need to send more ethers');
        if (msg.value > totalPrice) {
            payable(msgSender).transfer(msg.value - totalPrice);
        }

        mintedCount[msgSender] = accountNewMintCount;
        for (uint256 i = 0; i < quantity; i++) {
            _safeMint(msgSender, _tokenIds.current());
            _tokenIds.increment();
        }
    }

    function addWhitelist(
        bytes32 merkleRoot,
        uint256 quantity,
        uint256 price
    ) public onlyOwner {
        uint256 whiteListPlanIndex = whitelistPlansCounter.current();
        whitelistPlans[whiteListPlanIndex] = WhitelistInfo(merkleRoot, quantity, price);
        whitelistPlansCounter.increment();
        emit WhitelistAdded(merkleRoot, quantity, price);
    }

    function setContractMetadata(string memory _contractMetadata) public onlyOwner {
        contractMetadata = _contractMetadata;
    }

    function setStartBlock(uint256 _block) public onlyOwner {
        startBlock = _block;
        emit StartTimeUpdated(_block);
    }

    function setRoyalty(uint16 _royalty) public onlyOwner {
        require(_royalty >= 0 && _royalty <= 1000, 'CBL: Royalty must be between 0% and 10%');

        royalty = _royalty;
    }

    function setWithdrawAccount(address account) public onlyOwner {
        require(withdrawAccount != account, 'CBL: Already set');
        withdrawAccount = account;
    }

    function withdraw(uint256 _amount) public onlyWhitdrawable {
        uint256 balance = address(this).balance;
        require(_amount <= balance, 'CBL: Insufficient funds');

        bool success;
        (success, ) = payable(_msgSender()).call{value: _amount}('');
        require(success, 'CBL: Withdraw Failed');

        emit ContractWithdraw(_msgSender(), _amount);
    }

    function withdrawTokens(address _tokenContract) public onlyWhitdrawable {
        IERC20 tokenContract = IERC20(_tokenContract);

        uint256 _amount = tokenContract.balanceOf(address(this));
        tokenContract.transfer(_msgSender(), _amount);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }
    function _exists(uint256 tokenId) internal view override returns (bool) {
        return tokenId < _tokenIds.current();
    }

    event ContractWithdraw(address indexed withdrawAddress, uint256 amount);
    event WhitelistAdded(bytes32 merkleRoot, uint256 quantity, uint256 price);
    event StartTimeUpdated(uint256 blockNumber);
}
