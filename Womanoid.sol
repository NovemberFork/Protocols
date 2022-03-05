// SPDX-License-Identifier: GPL-3.
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
* @title WOMANOID ERC-721 Contract
* @author DegenDeveloper.eth
*
* The contract owner has the following permissions:
* - Open/close whitelist minting
* - Open/close public minting
* - Set the URI for the revealed tokens
* - Set the merkle root for the whitelist
* - Withdraw the funds from the contract
*/

contract Womanoid is ERC721, Ownable, ReentrancyGuard {

  /// ============ SETUP ============ ///

  using Counters for Counters.Counter;
  using Strings for uint256;
  
  Counters.Counter private totalMinted;

  bytes32 public merkleRoot;

  string internal URI;

  bool internal WHITELIST_SALE_ACTIVE = false;
  bool internal PUBLIC_SALE_ACTIVE = false; 
  bool internal REVEALED = false; 

  mapping(address => Counters.Counter) internal whiteListMints;

  uint256 internal constant PRICE = 100000000000000000; // 0.1 ETH 
  uint256 internal constant MAXSUPPLY = 8888;  
  uint256 internal constant MAXMINT = 15; 
   
  /// ============ CONSTRUCTOR ============ ///

  /**
  * @param _URI The ipfs hash for the unrevealed metadata (ipfs://<cid>)
  * @param _merkleRoot The root hash of the whitelist merkle tree (0x1234...9876)
  */
  constructor(string memory _URI, bytes32 _merkleRoot)
    ERC721("Womanoid", "WND") 
  {
    URI = _URI;
    merkleRoot = _merkleRoot;
  }

  /// ============ MINTING ============ ///

  /**
  * @param _minting The number of tokens to mint
  */
  function publicMint(uint256 _minting) public payable nonReentrant {
    require(PUBLIC_SALE_ACTIVE, "Public minting is not active");
    require(_minting <= MAXMINT, "Minting too many per transaction");
    require(_minting + totalMinted.current() <= MAXSUPPLY, "Minting this many would exceed the maximum supply");
    require(msg.value  >= PRICE * _minting, "Insufficient funds");
    
    for (uint256 i = 0; i < _minting; i++) {
      totalMinted.increment();
      _safeMint(msg.sender, totalMinted.current());
    }
  }

  /** 
  * @notice To whitelist mint, a user must use the dapp
  * @param _merkleProof The first part of the whitelist proof, supplied by the dapp
  * @param _allowed The second part of the whitelist proof, also supplied by the dapp
  * @param _minting The number of tokens to mint. Must be less than or equal to the number of _allowed tokens 
  */
  function whiteListMint(
    bytes32[] calldata _merkleProof,
    uint256 _allowed,
    uint256 _minting
  ) public payable nonReentrant {
    require(WHITELIST_SALE_ACTIVE, "Whitelist minting is not active");
    require(verifyProof(_merkleProof, _allowed), "Invalid proof, not on whitelist");
    require(
      _minting + whiteListMints[msg.sender].current() <= _allowed,
      "Cannot mint this many tokens"
    );
    require(_minting + totalMinted.current() <= MAXSUPPLY, "Minting this many would exceed the maximum supply");
    require(msg.value >= PRICE * _minting, "Insufficient funds");

    for (uint256 i = 0; i < _minting; i++) {
      whiteListMints[msg.sender].increment();
      totalMinted.increment();
      _safeMint(msg.sender, totalMinted.current());
      
    }
  }

  /// ============ OWNER FUNCTIONS ============ ///

  /**
  * @notice Open/close whitelist minting
  */
  function toggleWhitelistSale() public onlyOwner {
    WHITELIST_SALE_ACTIVE = !WHITELIST_SALE_ACTIVE;
  }

  /**
  * @dev Open/close public minting
  */
  function togglePublicSale() public onlyOwner {
    PUBLIC_SALE_ACTIVE = !PUBLIC_SALE_ACTIVE;
  }

  /**
  * @notice Toggles REVEAL using _newURI as the base for each token
  * @param _newURI The ipfs FOLDER containing all of the images (ex: 'ipfs://<cid>/', the ending '/' is required)
  */
  function toggleReveal(string memory _newURI) public onlyOwner {
    REVEALED = true;
    URI = _newURI;
  }

  /**
  * @notice Set new base URI for tokens if needed
  */
  function setURI(string memory _newURI) public onlyOwner {
    URI = _newURI;
  }

  /**
  * @notice Set new root hash for merkle tree if whitelist is updated
  * @param _merkleRoot Root hash for new whitelist merkle tree
  */
  function setMerkleRoot(bytes32 _merkleRoot) public onlyOwner {
    merkleRoot = _merkleRoot;
  }

  /**
  * @dev withdraw contractBalance to addr
  */
  function withdrawFunds(address payable addr) public onlyOwner {
    addr.transfer(contractBalance());
  }

  /// ============ CONTRACT FUNCTIONS ============ ///

  function verifyProof(bytes32[] calldata merkleProof, uint256 _allowed)
    internal
    view
    returns (bool)
  {
    return
      MerkleProof.verify(
        merkleProof,
        merkleRoot,
        keccak256(abi.encodePacked(msg.sender, _allowed))
      );
  }

  function tokenURI(uint256 tokenId)
    public
    view
    override
    returns (string memory)
  {
    if (REVEALED) {
      return string(abi.encodePacked(URI, tokenId.toString(), ".json"));
    }
    return URI;
  }

  function contractBalance() public view returns(uint256){
    return address(this).balance;
  }

  /// ============ PUBLIC FUNCTIONS ============ ///

  /**
  @return If whitelist minting is active
  */
  function getWhitelistSaleStatus() public view returns(bool){
    return WHITELIST_SALE_ACTIVE;
  }

  /**
  @return If public minting is active
  */
  function getPublicSaleStatus() public view returns(bool){
    return PUBLIC_SALE_ACTIVE;
  }

  /**
  @return If the tokens are revealed
  */
  function getRevealedStatus() public view returns(bool){
    return REVEALED;
  }

  /**
  @return The base URI
  */
  function getBaseURI() public view returns(string memory){
    return URI;
  }

  /**
  @return The price to mint 1 token (in wei)
  */
  function getMintPrice() public pure returns(uint256){
    return PRICE;
  }

  /**
  @return The max supply of the collection
  */
  function getTotalSupply() public pure returns(uint256){
    return MAXSUPPLY;
  }

  /**
  @return The number of tokens allowed per transaction
  */
  function getTokensPerTxn() public pure returns(uint256){
    return MAXMINT;
  }

  /**
  @return The number of tokens that have currently been minted
  */
  function getTokensMinted() public view returns(uint256){
    return totalMinted.current();
  }

  function getMerkleRoot() public view returns(bytes32){
      return merkleRoot;
  }

  /**
  * @param _addr The address to lookup
  * @return The 
  */
  function checkWhiteListStatus(address _addr) public view returns (uint256){
    return whiteListMints[_addr].current();
  }

}
