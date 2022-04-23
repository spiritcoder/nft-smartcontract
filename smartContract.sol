// SPDX-License-Identifier: MIT

pragma solidity >=0.8.9 <0.9.0;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract SimpleSmartContract is ERC721A, Ownable, ReentrancyGuard {
    using Strings for uint256;

    mapping(address => bool) private whitelistClaimed;
    mapping(address => bool) private privateSaleClaimed;
    mapping(address => bool) private raffleClaimed;

    string public uriPrefix = "";
    string public uriSuffix = ".json";
    string public hiddenMetadataUri;

    uint256 public cost;
    uint256 public maxSupply;
    uint256 public maxMintAmountPerTx;

    bool public revealed = false;

    address[] private whitelistedAddresses;
    address[] private raffleAddresses;
    address[] private privateSaleAddresses;

    // General constants
    enum mintTypes {
        PRIVATE,
        WHITELIST,
        RAFFLE,
        PUBLIC
    }

    // Constants for the private
    uint256 private privateMaxMintsPerTx = 10; // Maximum number of mints per transaction
    uint256 private privateMaxMintsPerWallet = 50; // Maximum number of mint per wallet
    uint256 public privateStartTime = 1649203200000; // UTC timestamp when minting is open
    bool public privateIsActive = false; // If the mint is active
    mapping(address => uint256) public privateAmountMinted; // Keep track of the amount mint during the private

    // Constants for the whitelist
    uint256 private whitelistMaxMintsPerTx = 2; // Maximum number of mints per transaction
    uint256 private whitelistMaxMintsPerWallet = 2; // Maximum number of mint per wallet
    uint256 public whitelistStartTime = 1649203200000; // UTC timestamp when minting is open
    bool public whitelistIsActive = false; // If the mint is active
    mapping(address => uint256) public whitelistAmountMinted; // Keep track of the amount mint during the whitelist

    // Constants for the raffle
    uint256 private raffleMaxMintsPerTx = 2; // Maximum number of mints per transaction
    uint256 private raffleMaxMintsPerWallet = 2; // Maximum number of mint per wallet
    uint256 public raffleStartTime = 1649203200000; // UTC timestamp when minting is open
    bool public raffleIsActive = false; // If the mint is active
    mapping(address => uint256) public raffleAmountMinted; // Keep track of the amount mint during the raffle

    // Constants for the public sale
    uint256 public publicMaxMintsPerTx = 2; // Maximum number of mints per transaction
    bool public publicIsActive = false; // If the mint is active
    uint256 public publicStartTime = 1649203200000; // UTC timestamp when minting is open

    //can do stuff
    bool public canWhitelist = false;
    bool public canRaffle = false;

    constructor(
        string memory _tokenName,
        string memory _tokenSymbol,
        uint256 _cost,
        uint256 _maxSupply,
        uint256 _maxMintAmountPerTx,
        string memory _hiddenMetadataUri
    ) ERC721A(_tokenName, _tokenSymbol) {
        cost = _cost;
        maxSupply = _maxSupply;
        maxMintAmountPerTx = _maxMintAmountPerTx;
        setHiddenMetadataUri(_hiddenMetadataUri);
    }

    modifier mintCompliance(uint256 _mintAmount) {
        require(
            _mintAmount > 0 && _mintAmount <= maxMintAmountPerTx,
            "Invalid mint amount!"
        );
        require(
            totalSupply() + _mintAmount <= maxSupply,
            "Max supply exceeded!"
        );
        _;
    }

    modifier mintPriceCompliance(uint256 _mintAmount) {
        require(msg.value >= cost * _mintAmount, "Insufficient funds!");
        _;
    }

    function whitelistMint(uint256 _mintAmount)
        public
        payable
        mintCompliance(_mintAmount)
        mintPriceCompliance(_mintAmount)
    {
        // Verify whitelist requirements
        require(whitelistIsActive, "The whitelist sale is not enabled!");
        require(!whitelistClaimed[_msgSender()], "Address already claimed!");
        require(isWhitelisted(msg.sender), "user is not whitelisted");
        _safeMint(_msgSender(), _mintAmount);
    }

    function raffleMint(uint256 _mintAmount)
        public
        payable
        mintCompliance(_mintAmount)
        mintPriceCompliance(_mintAmount)
    {
        // Verify whitelist requirements
        require(raffleIsActive, "The Raffle claim is not enabled!");
        require(!raffleClaimed[_msgSender()], "Address already claimed!");
        require(isRaffled(msg.sender), "user is not whitelisted");
        _safeMint(_msgSender(), _mintAmount);
    }

    function privateMint(uint256 _mintAmount)
        public
        payable
        mintCompliance(_mintAmount)
        mintPriceCompliance(_mintAmount)
    {
        // Verify whitelist requirements
        require(privateIsActive, "The Private claim is not enabled!");
        require(!privateSaleClaimed[_msgSender()], "Address already claimed!");
        require(
            isPrivateSaleWallet(msg.sender),
            "user is not on private sale list"
        );
        _safeMint(_msgSender(), _mintAmount);
    }

    function mint(uint256 _mintAmount)
        public
        payable
        mintCompliance(_mintAmount)
        mintPriceCompliance(_mintAmount)
    {
        require(publicIsActive, "Public sale has not started!");

        for (
            uint256 i = totalSupply();
            i < (totalSupply() + _mintAmount);
            i++
        ) {
            _safeMint(msg.sender, i + 1);
        }
    }

    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(_tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        if (revealed == false) {
            return hiddenMetadataUri;
        }

        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        _tokenId.toString(),
                        uriSuffix
                    )
                )
                : "";
    }

    function isWhitelisted(address _user) public view returns (bool) {
        for (uint256 i = 0; i < whitelistedAddresses.length; i++) {
            if (whitelistedAddresses[i] == _user) {
                return true;
            }
        }
        return false;
    }

    function isRaffled(address _user) public view returns (bool) {
        for (uint256 i = 0; i < raffleAddresses.length; i++) {
            if (raffleAddresses[i] == _user) {
                return true;
            }
        }
        return false;
    }

    function isPrivateSaleWallet(address _user) public view returns (bool) {
        for (uint256 i = 0; i < privateSaleAddresses.length; i++) {
            if (privateSaleAddresses[i] == _user) {
                return true;
            }
        }
        return false;
    }

    function whitelistUser(address _user) public {
        whitelistedAddresses.push(_user);
    }

    function privateListUser(address _user) public {
        privateSaleAddresses.push(_user);
    }

    function raffleListUser(address _user) public {
        raffleAddresses.push(_user);
    }

    //owner
    function setMaxMintsPerTx(uint256 _type, uint256 _newMax)
        external
        onlyOwner
    {
        if (_type == uint256(mintTypes.WHITELIST)) {
            whitelistMaxMintsPerTx = _newMax;
        } else if (_type == uint256(mintTypes.PRIVATE)) {
            privateMaxMintsPerTx = _newMax;
        } else if (_type == uint256(mintTypes.RAFFLE)) {
            raffleMaxMintsPerTx = _newMax;
        } else if (_type == uint256(mintTypes.PUBLIC)) {
            publicMaxMintsPerTx = _newMax;
        }
    }

    function setMaxMintsPerWallet(uint256 _type, uint256 _newMax)
        external
        onlyOwner
    {
        if (_type == uint256(mintTypes.WHITELIST)) {
            whitelistMaxMintsPerWallet = _newMax;
        } else if (_type == uint256(mintTypes.PRIVATE)) {
            privateMaxMintsPerWallet = _newMax;
        } else if (_type == uint256(mintTypes.RAFFLE)) {
            raffleMaxMintsPerWallet = _newMax;
        }
    }

    function setStartTime(uint256 _type, uint256 _startTime)
        external
        onlyOwner
    {
        if (_type == uint256(mintTypes.WHITELIST)) {
            whitelistStartTime = _startTime;
        } else if (_type == uint256(mintTypes.PRIVATE)) {
            privateStartTime = _startTime;
        } else if (_type == uint256(mintTypes.RAFFLE)) {
            raffleStartTime = _startTime;
        } else if (_type == uint256(mintTypes.PUBLIC)) {
            publicStartTime = _startTime;
        }
    }

    function setIsActive(uint256 _type, bool _isActive) external onlyOwner {
        if (_type == uint256(mintTypes.WHITELIST)) {
            whitelistIsActive = _isActive;
        } else if (_type == uint256(mintTypes.PRIVATE)) {
            privateIsActive = _isActive;
        } else if (_type == uint256(mintTypes.RAFFLE)) {
            raffleIsActive = _isActive;
        } else if (_type == uint256(mintTypes.PUBLIC)) {
            publicIsActive = _isActive;
        }
    }

    function setRevealed(bool _state) public onlyOwner {
        revealed = _state;
    }

    function setWhitelist(bool _state) public onlyOwner {
        canWhitelist = _state;
    }

    function setRaffle(bool _state) public onlyOwner {
        canRaffle = _state;
    }

    function setCost(uint256 _cost) public onlyOwner {
        cost = _cost;
    }

    function setMaxMintAmountPerTx(uint256 _maxMintAmountPerTx)
        public
        onlyOwner
    {
        maxMintAmountPerTx = _maxMintAmountPerTx;
    }

    function setHiddenMetadataUri(string memory _hiddenMetadataUri)
        public
        onlyOwner
    {
        hiddenMetadataUri = _hiddenMetadataUri;
    }

    function setUriPrefix(string memory _uriPrefix) public onlyOwner {
        uriPrefix = _uriPrefix;
    }

    function setUriSuffix(string memory _uriSuffix) public onlyOwner {
        uriSuffix = _uriSuffix;
    }

    function mintForAddress(uint256 _mintAmount, address _receiver)
        public
        mintCompliance(_mintAmount)
        onlyOwner
    {
        _safeMint(_receiver, _mintAmount);
    }

    function withdrawAll() public onlyOwner nonReentrant {
        (bool os, ) = payable(owner()).call{value: address(this).balance}("");
        require(os);
    }

    function withdrawAmount(uint256 _amount) public onlyOwner nonReentrant {
        require(
            address(this).balance >= _amount,
            "You cannot withdraw an amount greater than the smart contract balance"
        );
        (bool os, ) = payable(owner()).call{
            value: (address(this).balance - _amount)
        }("");
        require(os);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return uriPrefix;
    }
}

