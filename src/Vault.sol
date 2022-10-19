// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";

///@title Vault
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

    ///@notice Emitted when the contract is initialized.
    event Initialized(
        uint256 feeBps,
        uint256 auctionStart,
        uint256 auctionEnd,
        uint256 indexed reservePrice,
        uint256 supply,
        address admin,
        address indexed tokenAddress,
        uint256 indexed tokenId,
        string symbol,
        string name
    );
    ///@notice Emitted when the token is split into its constituent ERC20s.
    event Split();
    ///@notice Emitted when all consistuent ERC20 tokens are redeemed and the ERC721 is reclaimed.
    event Redeemed();
    ///@notice Emitted when the auction is bid upon.
    event Bid(address indexed bidder, uint256 amount);
    ///@notice Emitted when a share of the final auction price is claimed.
    event Claimed(address indexed receiver, uint256 allocation, uint256 fee);
    ///@notice Emitted when the highest bidder recieves the token in return.
    event Recieved();
    ///@notice Emitted when the reserve price is updated.
    event ReserveUpdated(uint256 indexed newReserve);
    ///@notice Emitted when the fee is updated.
    event FeeUpdated(uint256 indexed newBps);
    ///@notice Emitted when the auction start timestamp is updated.
    event StartUpdated(uint256 indexed newStart);
    ///@notice Emitted when the auction end timestamp is updated.
    event EndUpdated(uint256 indexed newEnd);

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

        emit Initialized(
            _feeBps, _auctionStart, _auctionEnd, _reservePrice, _supply, _admin, _tokenAddress, _tokenId, _symbol, _name
        );
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
        require(msg.value > currentBid);

        payable(highestBidder).transfer(currentBid);

        currentBid = msg.value;
        highestBidder = msg.sender;

        emit Bid(msg.sender, msg.value);
    }

    ///@notice Claim your share of Ether from the auction.
    function claim() external isAuctionOver {
        // Cache balance to save on SLOADs.
        uint256 senderBalance = balanceOf[msg.sender];

        require(auctionOver);
        require(senderBalance > 0);

        _burn(msg.sender, senderBalance);

        // uint256 allocation = currentBid / (100 / senderBalance);
        // uint256 fee = (allocation / 100) * (feeBps * 100);

        uint256 allocation;
        uint256 fee;

        assembly {
            let bidSlot := sload(currentBid.slot)
            let feeSlot := sload(feeBps.slot)

            allocation := div(bidSlot, div(100, senderBalance))
            fee := mul(div(allocation, 100), mul(feeSlot, 100))
        }

        payable(msg.sender).transfer(allocation - fee);

        emit Claimed(msg.sender, allocation, fee);
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
        assembly {
            let reserveSlot := reservePrice.slot
            sstore(reserveSlot, _newReserve)
        }

        emit ReserveUpdated(_newReserve);
    }

    ///@notice Update the fee.
    ///@param _newBps New basis point value for the fee.
    function updateFee(uint256 _newBps) external payable onlyAdmin {
        assembly {
            let bpsSlot := feeBps.slot
            sstore(bpsSlot, _newBps)
        }

        emit FeeUpdated(_newBps);
    }

    ///@notice Claim fees from the auction.
    ///@dev THIS IS CURRENTLY A VULNERABLE FUNCTION.
    function claimFee() external onlyAdmin {
        payable(msg.sender).transfer(address(this).balance);
    }

    ///@notice Update the start time of the auction.
    ///@param _newStart New timestamp value.
    function updateStart(uint256 _newStart) external payable onlyAdmin {
        require(
            (auctionEnd - _newStart) <= maxAuctionLength && 
            (auctionEnd - _newStart) >= minAuctionLength
        );

        assembly {
            let startSlot := auctionStart.slot
            sstore(startSlot, _newStart)
        }

        emit StartUpdated(_newStart);
    }

    ///@notice Update the end time of the auction.
    ///@param _newEnd New timestamp value.
    function updateEnd(uint256 _newEnd) external onlyAdmin {
        require(
            (_newEnd - auctionStart) <= maxAuctionLength && 
            (_newEnd - auctionStart) >= minAuctionLength
        );

        assembly {
            let endSlot := auctionEnd.slot
            sstore(endSlot, _newEnd)
        }

        emit EndUpdated(_newEnd);
    }
}
