//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/**
 * @author DegenDeveloper.eth
 * April 26, 2022
 *
 * This contract is for NovemberFork's Etheracts One.
 *
 * There is a max supply of 1111 tokens:
 *  - 1-11 were minted to NovemberFork.eth to hold for auctioning (11 total)
 *  - 12-22 were minted to DegenDeveloper.eth for his efforts (11 total)
 *  - 23-72 are reserved for seasons pass holders (50 total)
 *  - 73-172 are reserved for the airdrop (100 total)
 *  - 173-1111 are available to the public (939 total)
 *
 * In addition to utlity on NovemberFork.io, these tokens allow their owners to store the following parameters on chain:
 *  - a twitter handle
 *  - a paragraph
 *  - a website url
 *
 * These messages are only settable by their owners and will reset to empty strings when a token is sold/transferred.
 * The contract owner cannot change/delete/censor any messages unless they own the corresponding token
 *
 * The contract owner has the following permissions:
 *  - open/close minting
 *  - set a new tokenUri
 *  - withdraw the contract's funds
 *  - execute the airdrop (only if all public tokens have been minted)
 */
contract EtheractsOne is ERC721, Ownable {
  using Counters for Counters.Counter;
  using Strings for uint256;
  /// supply collection ///
  uint256 constant MAX_SUPPLY = 1111;
  /// mint price ///
  uint256 constant PRICE = 100 ether; // 100 MATIC on POLYGON
  /// identifier for the handle mapping ///
  bytes32 internal constant HANDLE = keccak256("HANDLE");
  /// identifier for the msg mapping ///
  bytes32 internal constant MSG = keccak256("MSG");
  /// identifier for the link mapping ///
  bytes32 internal constant LINK = keccak256("LINK");
  /// seasons pass contract instance ///
  ERC721 internal immutable SNPS;
  /// is minting active ///
  bool internal IS_MINTING = false;
  /// is collection revealed ///
  bool internal IS_REVEALED = false;
  /// uri base for tokens ///
  string internal URI;
  /// counter for the number of tokens minted by the public ///
  Counters.Counter internal publicMints;
  /// counter for the number of tokens minted by seasons pass holders ///
  Counters.Counter internal seasonsPassMints;
  /// counter for the number of airdrop participants ///
  Counters.Counter internal airdropParticipantCount;
  /// counter for the number of airdrop receivers selected ///
  Counters.Counter internal airdropsSelected;
  /// mapping of seasons pass ids => claimed status ///
  mapping(uint256 => bool) internal seasonsPassClaims;
  /// indexed mapping for each airdrop participant ///
  mapping(uint256 => address) internal airdropParticipants;
  /// indexed mapping for each airdrop receiver ///
  mapping(uint256 => address) internal airdropReceivers;
  /// mapping for token id => message identifier => value ///
  mapping(uint256 => mapping(bytes32 => string)) internal messages;

  /// ============ CONSTRUCTOR ============ ///

  constructor(string memory _baseURI, address _snpsAddress)
    ERC721("EtheractsOne", "Ethrx")
  {
    SNPS = ERC721(_snpsAddress);
    URI = _baseURI;
    // skip 150 for airdrops and season pass holders
    for (uint256 i = 1; i <= 11; ++i) {
      _safeMint(msg.sender, i);
    }
    for (uint256 i = 1; i <= 11; ++i) {
      _safeMint(msg.sender, i + 11);
    }
  }

  /// ============ OWNER FUNCTIONS ============ ///

  /**
   * Toggle if minting is allowed
   */
  function toggleMinting() public onlyOwner {
    IS_MINTING = !IS_MINTING;
  }

  /**
   * Reveal tokens with new baseURI
   * @param _newURI The ipfs folder of collection URIs
   */
  function toggleReveal(string memory _newURI) public onlyOwner {
    IS_REVEALED = true;
    URI = _newURI;
  }

  /**
   * For updating the token URIs
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

  /**
   * Performs the airdrop, sending 100 tokens to random minters
   */
  function executeAirdrop() public onlyOwner {
    require(publicMints.current() == 939, "Ethrx: Public minting not over");
    require(
      airdropsSelected.current() == 100,
      "Ethrx: Public minting not over"
    );
    for (uint256 i = 1; i <= airdropsSelected.current(); ++i) {
      _safeMint(airdropReceivers[i], i + 72);
    }
  }

  /// ============ PUBLIC FUNCTIONS ============ ///

  /**
   * Function for public to mint tokens
   * @param _amount Number of tokens caller is trying to mint
   * @notice public token ids are 173-1111
   */
  function publicMint(uint256 _amount) public payable {
    require(IS_MINTING, "Ethrx: Minting is not active");
    require(
      publicMints.current() + _amount + 172 <= MAX_SUPPLY,
      "Season Pass: Exceeds max supply"
    );
    require(msg.value >= PRICE * _amount, "Season Pass: Insufficent balance");
    for (uint256 i = 0; i < _amount; ++i) {
      /// increment counters ///
      publicMints.increment();
      airdropParticipantCount.increment();
      /// mint next token id to caller ///
      _safeMint(msg.sender, publicMints.current() + 172);
      /// add caller to airdropParticipants ///
      airdropParticipants[airdropParticipantCount.current()] = msg.sender;
      /// select airdrop receivers if milestone
      if (
        ((publicMints.current() + 172) >= 200) &&
        ((publicMints.current() + 172) % 50 == 0)
      ) {
        _airdropSelectorOne();
      } else if (
        ((publicMints.current() + 172) >= 222) &&
        ((publicMints.current() + 172) % 111 == 0)
      ) {
        _airdropSelectorTwo();
      }
    }
  }

  /**
   * Function for seasons pass holders to claim tokens
   * @notice seasons pass token ids are 23-72
   */
  function seasonsPassMint(uint256 _seasonsPassId) public {
    require(IS_MINTING, "Ethrx: Minting is not active");
    require(
      (_seasonsPassId > 0) && (_seasonsPassId <= 50),
      "Ethrx: Invalid _seasonsPassId"
    );
    require(
      SNPS.ownerOf(_seasonsPassId) == msg.sender,
      "Ethrx: Caller does not own  _seasonsPassId"
    );
    require(
      !seasonsPassClaims[_seasonsPassId],
      "Ethrx: Seasons pass already claimed"
    );
    seasonsPassClaims[_seasonsPassId] = true;
    _safeMint(msg.sender, 22 + _seasonsPassId);
    /// add caller to airdropParticipants ///
    airdropParticipantCount.increment();
    airdropParticipants[airdropParticipantCount.current()] = msg.sender;
    seasonsPassMints.increment();
  }

  /**
   * For setting all message values in one transaction
   * @param _id The token id to set message values for
   * @param _handle Caller's twitter handle
   * @param _msg Caller's msg
   * @param _link Caller's website
   */
  function setMessage(
    uint256 _id,
    string memory _handle,
    string memory _msg,
    string memory _link
  ) public {
    require(
      msg.sender == ownerOf(_id),
      "Ethrx: Caller does not own this token"
    );

    messages[_id][HANDLE] = _handle;
    messages[_id][MSG] = _msg;
    messages[_id][LINK] = _link;
  }

  /**
   * For setting a tokens handle
   * @param _handle Caller's twitter handle
   */
  function setHandle(uint256 _id, string memory _handle) public {
    require(
      msg.sender == ownerOf(_id),
      "Ethrx: Caller does not own this token"
    );

    messages[_id][HANDLE] = _handle;
  }

  /**
   * For setting a tokens msg
   * @param _msg Caller's paragraph
   */
  function setMsg(uint256 _id, string memory _msg) public {
    require(
      msg.sender == ownerOf(_id),
      "Ethrx: Caller does not own this token"
    );

    messages[_id][MSG] = _msg;
  }

  /**
   * For setting a tokens link
   * @param _link Caller's website
   */
  function setLink(uint256 _id, string memory _link) public {
    require(
      msg.sender == ownerOf(_id),
      "Ethrx: Caller does not own this token"
    );

    messages[_id][LINK] = _link;
  }

  /// ============ INTERNAL FUNCTIONS ============ ///

  /**
   * Selects 1 random address from the airdrop participants
   */
  function _airdropSelectorOne() internal {
    airdropsSelected.increment();
    airdropReceivers[airdropsSelected.current()] = airdropParticipants[
      _makePsuedoRandomNumber()
    ];
  }

  /**
   * Selects 9 random addresses from the airdrop participants
   */
  function _airdropSelectorTwo() internal {
    for (uint256 i = 0; i < 9; ++i) {
      airdropsSelected.increment();
      airdropReceivers[airdropsSelected.current()] = airdropParticipants[
        _makePsuedoRandomNumber()
      ];
    }
  }

  /**
   * Creates a pseudo random number in range[1, airdropParticipantCount.current()]
   * @notice This pseudo random number is not a true random number
   * @notice For an attacker to maniuplate the value of this pseudo random number to their favor they will
   * need to balance/get lucky/time their transaction perfectly taking into account:
   *    - the last 3 minters' addresses
   *    - the block.timestamp
   *    - their own address
   *    - and the number of airdrops currently selected
   * @notice We consider this to be very tricky and not worth an attackers time/funds
   * Feel free to try, we'll consider it a big brain achievement and maybe even airdrop you something else for your effort
   */
  function _makePsuedoRandomNumber() internal view returns (uint256 _index) {
    uint256 end = airdropParticipantCount.current();
    _index =
      (uint256(
        keccak256(
          abi.encodePacked(
            airdropParticipants[end],
            airdropParticipants[end - 1],
            airdropParticipants[end - 2],
            block.timestamp,
            msg.sender,
            airdropsSelected.current()
          )
        )
      ) % end) +
      1;
  }

  /**
   * @notice overrides OpenZeppelin's _beforeTokenTransfer to perform preset functionality and also
   * reset message values for the transferred token id
   */
  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal virtual override {
    super._beforeTokenTransfer(from, to, tokenId); // calls the original (non-overridden) _beforeTokenTransfer function
    messages[tokenId][HANDLE] = "";
    messages[tokenId][MSG] = "";
    messages[tokenId][LINK] = "";
  }

  /// ============ READ-ONLY FUNCTIONS ============ ///

  /**
   * @return _isMinting Is minting currently allowed ?
   */
  function isMinting() public view returns (bool _isMinting) {
    _isMinting = IS_MINTING;
  }

  /**
   * @return _isRevealed Is the collection revealed ?
   */
  function isRevealed() public view returns (bool _isRevealed) {
    _isRevealed = IS_REVEALED;
  }

  /**
   * @return _price The price to mint 1 token
   */
  function getPrice() public pure returns (uint256 _price) {
    _price = PRICE;
  }

  /**
   * @param _supply The collection's supply
   */
  function totalSupply() public pure returns (uint256 _supply) {
    _supply = MAX_SUPPLY;
  }

  /**
   * @return _uri The URI base for each token
   */
  function getURI() public view returns (string memory _uri) {
    _uri = URI;
  }

  /**
   * @param _tokenId The token id to lookup
   * @return _uri The full URI for _tokenId
   */
  function tokenURI(uint256 _tokenId)
    public
    view
    override
    returns (string memory _uri)
  {
    if (IS_REVEALED) {
      _uri = string(abi.encodePacked(URI, _tokenId.toString(), ".json"));
    } else {
      _uri = URI;
    }
  }

  /**
   * @return _mints The total number of ethrx minted from the contract
   * @notice Includes:
   *    - the 11 minted to NovemberFork.eth for auctioning
   *    - the 11 minted to DegenDeveloper.eth for his efforts
   *    - the number of public mints
   *    - the number of seasons pass claims
   */
  function totalMinted() public view returns (uint256 _mints) {
    _mints = publicMints.current() + seasonsPassMints.current() + 22;
  }

  /**
   * @return _mints The total number of ethrx minted by the public
   */
  function totalMintedByPublic() public view returns (uint256 _mints) {
    _mints = publicMints.current();
  }

  /**
   * @return _mints The total number of ethrx claimed by seasons pass holders
   */
  function totalMintedByPassHolders() public view returns (uint256 _mints) {
    _mints = seasonsPassMints.current();
  }

  /**
   * @param _seasonsPassId The seasons pass token id
   * @return _isClaimed If this seasons pass has claimed their free ethrx
   */
  function isSeasonsPassClaimed(uint256 _seasonsPassId)
    public
    view
    returns (bool _isClaimed)
  {
    _isClaimed = seasonsPassClaims[_seasonsPassId];
  }

  /**
   * @return _selected The number of airdrop receivers selected so far
   */
  function getAirdropsSelected() public view returns (uint256 _selected) {
    _selected = airdropsSelected.current();
  }

  /**
   * Get the address for an airdrop receiver by index
   * @param _index The index of the airdrop receiver
   * @param _receiver The address for the airdrop receiver
   */
  function getAirdropReceiver(uint256 _index)
    public
    view
    returns (address _receiver)
  {
    _receiver = airdropReceivers[_index];
  }

  /**
   * Gets the number of mints by _operator
   * @param _operator The address to lookup
   * @return _count The number of ethrx _operator has minted
   * @notice To calulate chances for receiving an airdrop, divide this result by the result from
   * `getAirdropParticipantCount()`
   */
  function getAirdropChances(address _operator)
    public
    view
    returns (uint256 _count)
  {
    for (uint256 i = 1; i <= airdropParticipantCount.current(); ++i) {
      if (airdropParticipants[i] == _operator) {
        _count += 1;
      }
    }
  }

  /**
   * @return _participants The number of addresses elgible for the airdrop currently
   */
  function getAirdropParticipantCount()
    public
    view
    returns (uint256 _participants)
  {
    _participants = airdropParticipantCount.current();
  }

  /**
   * For getting a token's message
   * @param _id The token to lookup
   * @return _handle Twitter handle set by _id owner
   * @return _msg Paragraph set by _id owner
   * @return _link Website set by _id owner
   */
  function getMessage(uint256 _id)
    public
    view
    returns (
      string memory _handle,
      string memory _msg,
      string memory _link
    )
  {
    _handle = messages[_id][HANDLE];
    _msg = messages[_id][MSG];
    _link = messages[_id][LINK];
  }
}
