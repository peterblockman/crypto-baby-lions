// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '@openzeppelin/contracts/interfaces/IERC20.sol';
import '@openzeppelin/contracts/interfaces/IERC165.sol';
import '@openzeppelin/contracts/interfaces/IERC2981.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract LittleLions is Ownable, ERC721Enumerable, IERC2981 {
    using Strings for uint256;
    using Counters for Counters.Counter;

    string private baseURI;
    string private contractMetadata;
    uint256 public startBlock = type(uint256).max;
    uint16 internal royalty = 500; // base 10000, 5%
    uint16 internal reservedTokens;
    uint16 public constant BASE = 10000;
    uint256 public constant MAX_TOKENS = 10000;
    uint256 public constant MAX_MINT = 3;
    uint256 public constant MINT_PRICE = 0.05 ether;

    Counters.Counter private _tokenIds;
    address public withdrawAccount;
    mapping(address => uint256) private mintWhitelist;
    mapping(address => uint256) private mintCount;

    constructor(string memory _contractMetadata, string memory baseURI_) ERC721('Little Lions', 'LiL') {
        contractMetadata = _contractMetadata;
        baseURI = baseURI_;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721Enumerable, IERC165)
        returns (bool)
    {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), 'LittleLions: URI query for nonexistent token');

        string memory baseContractURI = _baseURI();
        return bytes(baseContractURI).length > 0 ? string(abi.encodePacked(baseContractURI, tokenId.toString())) : '';
    }

    function contractURI() public view returns (string memory) {
        return contractMetadata;
    }

    function royaltyInfo(uint256, uint256 _salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        return (address(this), (_salePrice * royalty) / BASE);
    }

    function mint(uint256 quantity) public payable onlyOwner {
        require(_tokenIds.current() + quantity < MAX_TOKENS, 'LittleLions:All tokens are minted');

        uint256 accountNewMintCount = mintCount[msg.sender] + quantity;

        if (mintWhitelist[msg.sender] > 0) {
            require(accountNewMintCount <= mintWhitelist[msg.sender], 'LittleLions:All of your tokens are minted');
        } else {
            require(accountNewMintCount < MAX_MINT, 'LittleLions:All of your tokens are minted');
            require(startBlock <= block.number, 'LittleLions:Minting time is not started');
            uint256 price = quantity * MINT_PRICE;
            require(msg.value >= price, 'LittleLions:Need to send more ETH');
            if (msg.value > price) {
                payable(msg.sender).transfer(msg.value - price);
            }
        }

        mintCount[msg.sender] = accountNewMintCount;
        for (uint256 i = 0; i < quantity; i++) {
            _tokenIds.increment();
            _safeMint(msg.sender, _tokenIds.current());
        }
    }

    function setStartBlock(uint256 _block) public onlyOwner {
        startBlock = _block;
        emit StartTimeUpdated(_block);
    }

    function setBaseURI(string memory baseContractURI) public onlyOwner {
        baseURI = baseContractURI;
    }

    function setRoyalty(uint16 _royalty) public onlyOwner {
        require(_royalty >= 0 && _royalty <= 1000, 'LittleLions:Royalty must be between 0% and 10%.');

        royalty = _royalty;
    }

    function addWhitelist(address[] memory accounts, uint256 quantity) public onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            mintWhitelist[accounts[i]] = quantity;
        }
        emit WhitelistAdded(accounts, quantity);
    }

    function setWithdrawAccount(address account) public onlyOwner {
        require(withdrawAccount != account, 'LittleLions:Already set');
        withdrawAccount = account;
    }

    function withdraw(uint256 _amount) public {
        require(msg.sender == withdrawAccount, 'LittleLions:Not allowed');

        uint256 balance = address(this).balance;
        require(_amount <= balance, 'LittleLions:Insufficient funds');

        bool success;
        (success, ) = payable(msg.sender).call{value: _amount}('');
        require(success, 'LittleLions:Withdraw Failed');

        emit ContractWithdraw(msg.sender, msg.sender, _amount);
    }

    function withdrawTokens(address _tokenContract) public {
        require(msg.sender == withdrawAccount, 'LittleLions:Not allowed');
        IERC20 tokenContract = IERC20(_tokenContract);

        uint256 _amount = tokenContract.balanceOf(address(this));
        tokenContract.transfer(msg.sender, _amount);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    event ContractWithdraw(address indexed initiator, address indexed withdrawAddress, uint256 amount);
    event WhitelistAdded(address[] accounts, uint256 quantity);
    event StartTimeUpdated(uint256 blockNumber);
}
