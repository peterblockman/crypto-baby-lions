// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '@openzeppelin/contracts/interfaces/IERC20.sol';
import '@openzeppelin/contracts/interfaces/IERC165.sol';
import '@openzeppelin/contracts/interfaces/IERC2981.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract CryptoBabyLions is Ownable, ERC721('Crypto Baby Lions', 'CBL'), IERC2981 {
    using Strings for uint256;
    using Counters for Counters.Counter;

    struct WhitelistInfo {
        uint256 quantity;
        uint256 price;
    }

    uint16 internal royalty = 500; // base 10000, 5%
    uint16 public constant BASE = 10000;
    uint256 public constant MAX_TOKENS = 10000;
    uint256 public constant MAX_MINT = 3;
    uint256 public constant MINT_PRICE = 0.05 ether;
    uint256 public startBlock = type(uint256).max;

    string private baseURI;
    string private contractMetadata;
    address public withdrawAccount;
    Counters.Counter private _tokenIds;

    Counters.Counter private whitelistPlansCounter;
    mapping(uint256 => WhitelistInfo) private whitelistPlans;
    mapping(address => uint256) private mintWhitelist;
    mapping(address => uint256) private mintedCount;

    constructor(string memory _contractMetadata, string memory baseURI_) {
        contractMetadata = _contractMetadata;
        baseURI = baseURI_;
        whitelistPlansCounter.increment();
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, IERC165) returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), 'CBL: URI query for nonexistent token');

        string memory baseContractURI = _baseURI();
        return bytes(baseContractURI).length > 0 ? string(abi.encodePacked(baseContractURI, tokenId.toString())) : '';
    }

    function contractURI() public view returns (string memory) {
        return contractMetadata;
    }

    function totalSupply() public view returns (uint256) {
        return _tokenIds.current();
    }

    function royaltyInfo(uint256, uint256 _salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        return (address(this), (_salePrice * royalty) / BASE);
    }

    function mint(uint256 quantity) public payable {
        require(_tokenIds.current() + quantity < MAX_TOKENS, 'CBL: That many tokens are not available');

        uint256 accountNewMintCount = mintedCount[msg.sender] + quantity;
        uint256 whitelistPlan = mintWhitelist[msg.sender];
        WhitelistInfo memory whitelistInfo = whitelistPlans[whitelistPlan];

        uint256 price = MINT_PRICE;

        if (whitelistPlan > 0) {
            require(accountNewMintCount <= whitelistInfo.quantity, 'CBL: That many tokens are not available for you');
            price = whitelistInfo.price;
        } else {
            require(accountNewMintCount <= MAX_MINT, 'CBL: That many tokens are not available for you');
            require(startBlock <= block.number, 'CBL: Minting time is not started');
        }

        uint256 totalPrice = quantity * price;
        require(msg.value >= totalPrice, 'CBL: Need to send more ethers');
        if (msg.value > totalPrice) {
            payable(msg.sender).transfer(msg.value - totalPrice);
        }

        mintedCount[msg.sender] = accountNewMintCount;
        for (uint256 i = 0; i < quantity; i++) {
            _tokenIds.increment();
            _safeMint(msg.sender, _tokenIds.current());
        }
    }

    function addWhitelist(
        address[] memory accounts,
        uint256 quantity,
        uint256 price
    ) public onlyOwner {
        uint whiteListPlanIndex = whitelistPlansCounter.current();
        whitelistPlans[whiteListPlanIndex] = WhitelistInfo(quantity, price);
        for (uint256 i = 0; i < accounts.length; i++) {
            mintWhitelist[accounts[i]] = whiteListPlanIndex;
        }
        whitelistPlansCounter.increment();
        emit WhitelistAdded(accounts, quantity, price);
    }

    function setStartBlock(uint256 _block) public onlyOwner {
        startBlock = _block;
        emit StartTimeUpdated(_block);
    }

    function setBaseURI(string memory baseContractURI) public onlyOwner {
        baseURI = baseContractURI;
    }

    function setRoyalty(uint16 _royalty) public onlyOwner {
        require(_royalty >= 0 && _royalty <= 1000, 'CBL: Royalty must be between 0% and 10%.');

        royalty = _royalty;
    }

    function setWithdrawAccount(address account) public onlyOwner {
        require(withdrawAccount != account, 'CBL:Already set');
        withdrawAccount = account;
    }

    function withdraw(uint256 _amount) public {
        require(msg.sender == withdrawAccount, 'CBL:Not allowed');

        uint256 balance = address(this).balance;
        require(_amount <= balance, 'CBL:Insufficient funds');

        bool success;
        (success, ) = payable(msg.sender).call{value: _amount}('');
        require(success, 'CBL:Withdraw Failed');

        emit ContractWithdraw(msg.sender, _amount);
    }

    function withdrawTokens(address _tokenContract) public {
        require(msg.sender == withdrawAccount, 'CBL:Not allowed');
        IERC20 tokenContract = IERC20(_tokenContract);

        uint256 _amount = tokenContract.balanceOf(address(this));
        tokenContract.transfer(msg.sender, _amount);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    event ContractWithdraw(address indexed withdrawAddress, uint256 amount);
    event WhitelistAdded(address[] accounts, uint256 quantity, uint256 price);
    event StartTimeUpdated(uint256 blockNumber);
}
