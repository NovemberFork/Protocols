//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/**
 * @author DegenDeveloper.eth
 * April 26th, 2022
 *
 * This contract is for seasons passes to NovemberFork.
 * There is a max supply of 50 tokens.
 * Users can only mint 1 token per address.
 *
 * Each collection in season one will reserve 50 tokens.
 * Owners of these tokens can claim their reserved tokens for free.
 *
 * The images for these tokens will update occasionally as the Koi painting is worked on
 *
 * The contract owner has the following permissions
 *  - open/close minting
 *  - set a new tokenUri
 *  - withdraw the contract's funds
 */
contract SeasonsPass is ERC721, Ownable {
  using Counters for Counters.Counter;
  using Strings for uint256;
  /// counter for the number of token mints ///
  Counters.Counter internal totalMints;
  /// supply collection ///
  uint256 constant MAX_SUPPLY = 50;
  /// mint price ///
  uint256 constant PRICE = 50 ether; // 50 MATIC on POLYGON
  /// is minting active ///
  bool internal IS_MINTING = false;
  /// uri base for tokens ///
  string internal URI;
  /// mapping for storing if an address has minted before ///
  mapping(address => bool) internal hasMinted;

  /// ============ CONSTRUCTOR ============ ///

  /**
   * Mints the first season pass to the contract owner
   * @param _baseURI The URI base for each token
   */
  constructor(string memory _baseURI) ERC721("SeasonsPass", "SNPS") {
    URI = _baseURI;
    totalMints.increment();
    hasMinted[msg.sender] = true;
    _safeMint(msg.sender, totalMints.current());
  }

  /// ============ PUBLIC FUNCTIONS ============ ///

  /**
   * Mints 1 season pass to caller
   * @notice Caller can only mint once
   * @return _id The token id minted to caller
   */
  function mintSeasonsPass() external payable returns (uint256 _id) {
    require(IS_MINTING, "Season Pass: Minting is not active");
    require(!hasMinted[msg.sender], "Season Pass: Token already claimed");
    require(
      totalMints.current() < MAX_SUPPLY,
      "Season Pass: Exceeds max supply"
    );
    require(msg.value >= PRICE, "Season Pass: Insufficent balance");
    totalMints.increment();
    _id = totalMints.current();
    hasMinted[msg.sender] = true;
    _safeMint(msg.sender, _id);
  }

  /// ============ OWNER FUNCTIONS ============ ///

  /**
   * Toggle if minting is allowed
   */
  function toggleMinting() public onlyOwner {
    IS_MINTING = !IS_MINTING;
  }

  /**
   * For updating the progress of the koi painting
   * @param _baseURI The new URI base for each token
   */
  function setURI(string memory _baseURI) public onlyOwner {
    URI = _baseURI;
  }

  /**
   * For withdrawing contract funds to a specific address
   * @param _addr The receiver of the funds
   */
  function withdrawFunds(address payable _addr) public onlyOwner {
    _addr.transfer(address(this).balance);
  }

  /// ============ READ-ONLY FUNCTIONS ============ ///

  /**
   * @return _isMinting If minting is currently allowed
   */
  function isMinting() public view returns (bool _isMinting) {
    _isMinting = IS_MINTING;
  }

  /**
   * @return _price The price to mint 1 token
   */
  function getPrice() public pure returns (uint256 _price) {
    _price = PRICE;
  }

  /**
   * @return _mints The number of tokens currently minted
   */
  function totalMinted() public view returns (uint256 _mints) {
    _mints = totalMints.current();
  }

  /**
   * @return _supply The max number of tokens in the collection
   */
  function totalSupply() public pure returns (uint256 _supply) {
    _supply = MAX_SUPPLY;
  }

  /**
   * return _uri The URI base for each token
   */
  function getURI() public view returns (string memory _uri) {
    _uri = URI;
  }

  /**
   * Gets the URI for a specifc token id
   * @param _tokenId The token id to lookup
   * @return _uri The URI link for _tokenId
   */
  function tokenURI(uint256 _tokenId)
    public
    view
    override
    returns (string memory _uri)
  {
    _uri = string(abi.encodePacked(URI, _tokenId.toString(), ".json"));
  }
}
