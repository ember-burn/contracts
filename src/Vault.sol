// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";

//TODO: AuctionOver modifier
///@notice Core fractionalization primitive.
///@author Zach
contract Vault is ERC20 {
    /*//////////////////////////////////////////////////////////////
                                  STATE
    //////////////////////////////////////////////////////////////*/

    ///@notice Basis point representation of the protocol fee.
    uint256 public feeBps;
    ///@notice Timestamp of auction start.
    uint256 public auctionStart;
    ///@notice Timestamp of auction end.
    uint256 public auctionEnd;
    ///@notice Current reserve price in Ether.
    uint256 public reservePrice;
    ///@notice Current auction bid in Ether.
    uint256 public currentBid;

    ///@notice Track whether auction is active or inactive.
    bool public auctionActive;
    ///@notice Track whether auction is over or not.
    bool public auctionOver;
    ///@notice Address representing the administrator of the vault.
    ///@dev Admin should usually be the owner of the fractionalized token, as they have a lot of granular control over the vault.
    address public admin;
    ///@notice Address of the highest bidder of the auction.
    address public highestBidder;

    ///@notice Immutable variable representing the minimum auction length.
    uint256 immutable minAuctionLength;
    ///@notice Immutable variable representing the maximum auction length.
    uint256 immutable maxAuctionLength;
    ///@notice Amount of tokens in circulation.
    uint256 immutable supply;
    ///@notice ID of the token according to the ERC721 specification.
    uint256 immutable tokenId;
    ///@notice Token address of the fractionalized item.
    address immutable tokenAddress;

    /*//////////////////////////////////////////////////////////////
                                  EVENT
    //////////////////////////////////////////////////////////////*/

    ///@notice Emitted when the token is fractionalized.
    event Split();
    ///@notice Emitted when all consistuent ERC20 tokens are redeemed and the ERC721 is reclaimed.
    event Redeemed();
    ///@notice Emitted when the auction is bid upon.
    event Bid();
    ///@notice Emitted when a share of the final auction price is claimed.
    event Claimed();
    ///@notice Emitted when the highest bidder recieves the token in return.
    event Recieved();
    ///@notice Emitted when the reserve price is updated.
    event ReserveUpdated();
    ///@notice Emitted when the fee is updated.
    event FeeUpdated();
    ///@notice Emitted when the auction start timestamp is updated.
    event StartUpdated();
    ///@notice Emitted when the auction end timestamp is updated.
    event EndUpdated();

    /*//////////////////////////////////////////////////////////////
                                MODIFIER
    //////////////////////////////////////////////////////////////*/

    ///@notice Update auction status: active or inactive.
    modifier isAuctionActive() {
        if (block.timestamp >= auctionStart) {
            auctionActive = true;
        }
        _;
    }

    ///@notice Update auction status: over or not over;
    ///@dev There is a subtle distinction between 'active' and 'over.' 'Over' refers to when the end timestamp has been exceeded, whereas 'active' refers to either before the auction has begun or afterwards.
    modifier isAuctionOver() {
        if (block.timestamp >= auctionEnd) {
            auctionOver = true;
        }
        _;
    }

    ///@notice Ensure admin is the only address that can call a function.
    modifier onlyAdmin() {
        require(msg.sender == admin);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                INTERFACE
    //////////////////////////////////////////////////////////////*/

    ///@notice Initialize vault
    ///@dev See identically named state variables for parameter descriptions.
    ///@param _feeBps feeBps
    ///@param _auctionStart auctionStart
    ///@param _auctionEnd auctionEnd
    ///@param _minAuctionLength minAuctionLength
    ///@param _maxAuctionLength maxAuctionLength
    ///@param _reservePrice reservePrice
    ///@param _supply supply
    ///@param _admin admin
    ///@param _tokenAddress tokenAddress
    ///@param _tokenId tokenId
    ///@param _symbol symbol
    ///@param _name name
    constructor(
        uint256 _feeBps,
        uint256 _auctionStart,
        uint256 _auctionEnd,
        uint256 _minAuctionLength,
        uint256 _maxAuctionLength,
        uint256 _reservePrice,
        uint256 _supply,
        address _admin,
        address _tokenAddress,
        uint256 _tokenId,
        string memory _symbol,
        string memory _name
    ) ERC20(_name, _symbol, 18) {
        require((_auctionEnd - _auctionStart) > _minAuctionLength && (_auctionEnd - _auctionStart) > _maxAuctionLength);

        feeBps = _feeBps;
        auctionStart = _auctionStart;
        auctionEnd = _auctionEnd;
        minAuctionLength = _minAuctionLength;
        maxAuctionLength = _maxAuctionLength;
        reservePrice = _reservePrice;
        admin = _admin;
        supply = _supply;
        tokenId = _tokenId;
        tokenAddress = _tokenAddress;
        auctionActive = false;
        auctionOver = false;
        currentBid = 0;

        ERC721(tokenAddress).transferFrom(msg.sender, address(this), tokenId);
    }

    ///@notice Split a token into its constituent ERC20 fractions.
    function split() external onlyAdmin {
        _mint(msg.sender, supply);

        emit Split();
    }

    ///@notice Given a full set of 'fractions,' redeem the underlying ERC721 token.
    ///@dev You must have every single token for this function to execute.
    function redeem() external isAuctionActive {
        require(!auctionActive);
        require(balanceOf[msg.sender] == supply);

        _burn(msg.sender, supply);
        ERC721(tokenAddress).transferFrom(address(this), msg.sender, tokenId);

        emit Redeemed();
    }

    ///@notice Bid on the auction.
    function bid() external payable isAuctionActive {
        require(auctionActive);
        require(msg.value > reservePrice);

        payable(highestBidder).transfer(currentBid);

        currentBid = msg.value;
        highestBidder = msg.sender;

        emit Bid();
    }

    ///@notice Claim your share of Ether from the auction.
    function claim() external isAuctionOver {
        // Cache balance to save on SLOADs.
        uint256 senderBalance = balanceOf[msg.sender];

        require(auctionOver);
        require(senderBalance > 0);

        _burn(msg.sender, senderBalance);
        payable(msg.sender).transfer(currentBid / (100 / senderBalance));

        emit Claimed();
    }

    ///@notice Claim token from contract if auction is over and calling address is the highest bidder.
    function recieve() external isAuctionOver {
        require(auctionOver);
        require(msg.sender == highestBidder);

        ERC721(tokenAddress).safeTransferFrom(address(this), msg.sender, tokenId);

        emit Recieved();
    }

    /*//////////////////////////////////////////////////////////////
                                 SETTING
    //////////////////////////////////////////////////////////////*/

    ///@notice Update the reserve price.
    ///@param _newReserve Updated value.
    function updateReserve(uint256 _newReserve) external onlyAdmin {
        reservePrice = _newReserve;

        emit ReserveUpdated();
    }

    ///@notice Update the fee.
    ///@param _newBps New basis point value for the fee.
    function updateFee(uint256 _newBps) external onlyAdmin {
        feeBps = _newBps;

        emit FeeUpdated();
    }

    ///@notice Update the start time of the auction.
    ///@param _newStart New timestamp value.
    function updateStart(uint256 _newStart) external onlyAdmin {
        require((auctionEnd - _newStart) <= maxAuctionLength && (auctionEnd - _newStart) >= minAuctionLength);

        auctionStart = _newStart;

        emit StartUpdated();
    }

    ///@notice Update the end time of the auction.
    ///@param _newEnd New timestamp value.
    function updateEnd(uint256 _newEnd) external onlyAdmin {
        require((_newEnd - auctionStart) <= maxAuctionLength && (_newEnd - auctionStart) >= minAuctionLength);

        auctionEnd = _newEnd;

        emit EndUpdated();
    }
}