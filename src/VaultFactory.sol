// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Vault} from './Vault.sol';

///@title VaultFactory
///@notice Primary user interface for the protocol.
///@author Zach
contract VaultFactory {
	    
	/*//////////////////////////////////////////////////////////////
                                  STATE
    //////////////////////////////////////////////////////////////*/
	
	///@notice Index of the next vault.
	uint256 public vaultIndex;
	///@notice Minimum auction length in seconds (UNIX timestamp).
	uint256 public minAuctionLength;
	///@notice Maximum auction length in seconds (UNIX timestamp)
	uint256 public maxAuctionLength;

	///@notice Address of the protocol admin.
	///@dev It is recommended this address is a multi-signature wallet for security.
	address public admin;

	///@notice Maps an index to the corresponding vault. 
	mapping (uint256 => Vault) public vaults;
    
	/*//////////////////////////////////////////////////////////////
                                  EVENT
    //////////////////////////////////////////////////////////////*/

	///@notice Emitted when a vault is created.
	///@param index Index of vault.
	///@param feeBps Basis point representation of fee.
	///@param auctionStart Timestamp of auction start.
	///@param auctionEnd Timestamp of auction end.
	///@param reservePrice Reserve price of the token auction.
	///@param supply Supply of the fraction token.
	///@param tokenAddress Address of the ERC721 token.
	///@param tokenId ID of the ERC721 token.
	///@param symbol Symbol of the fraction ERC20 token.
	///@param name Name of the fraction ERC20 token.
	///@param salt Salt for contract creation. Allows vault address to be derived deterministically.
	event VaultCreated(
		uint256 indexed index,
		uint256 feeBps,
        uint256 auctionStart,
        uint256 auctionEnd,
        uint256 reservePrice,
		uint256 supply,
		address indexed tokenAddress,
		uint256 indexed tokenId,
		string symbol,
		string name,
		bytes32 salt
	);

	///@notice Emitted when the admin address is changed.
	///@param oldAdmin Old address of the admin.
	///@param newAdmin New address of the admin.
	event AdminChanged(
		address indexed oldAdmin,
		address indexed newAdmin
	);

	///@notice Emitted when the minimum auction length is changed.
	///@param oldMinimum Old minimum length.
	///@param newMinimum New minimum length.
	event AuctionMinimumChanged(
		uint256 indexed oldMinimum,
		uint256 indexed newMinimum
	);

	///@notice Emitted when the maximum auction length is changed.
	///@param oldMaximum Old maximum length.
	///@param newMaximum New maximum length.
	event AuctionMaximumChanged(
		uint256 indexed oldMaximum,
		uint256 indexed newMaximum
	);

	///@notice Ensure admin is the only address that can call a function.
	modifier onlyAdmin {
		require(msg.sender == admin);
		_;
	}

	/*//////////////////////////////////////////////////////////////
                                INTERFACE
    //////////////////////////////////////////////////////////////*/

	///@notice Initialize and deploy contract factory.
	///@param _minAuctionLength Initial maximum auction length.
	///@param _maxAuctionLength Initial minimum auction length.
	///@param _admin Initial admin address.
	constructor(
		uint256 _minAuctionLength,
		uint256 _maxAuctionLength,
		address _admin
	) {
		minAuctionLength = _minAuctionLength;
		maxAuctionLength = _maxAuctionLength;

		admin = _admin;
	}

	///@notice Create a vault.
	///@return Index + 1 of vault.
	///@dev See event documentation.
	function createVault(
		uint256 _feeBps,
        uint256 _auctionStart,
        uint256 _auctionEnd,
        uint256 _reservePrice,
		uint256 _supply,
		address _tokenAddress,
		uint256 _tokenId,
		address _admin,
		string memory _symbol,
		string memory _name,
		bytes32 _salt
	) external returns (uint256) {
		Vault vault = (new Vault) {salt: _salt} (
			_feeBps,
			_auctionStart,
			_auctionEnd,
			minAuctionLength,
			maxAuctionLength,
			_reservePrice,
			_supply,
			_admin,
			_tokenAddress,
			_tokenId,
			_symbol,
			_name
		);
		vaults[vaultIndex] = vault;

		emit VaultCreated(
			vaultIndex,
			_feeBps,
			_auctionStart,
			_auctionEnd,
			_reservePrice,
			_supply,
			_tokenAddress,
			_tokenId,
			_symbol,
			_name,
			_salt
		);

		return ++vaultIndex;
	}

	///@notice Change the current admin address. Only callable by the current admin.
	///@param _admin New admin address.
	function changeAdmin(address _admin) external onlyAdmin {
		admin = _admin;

		emit AdminChanged(msg.sender, _admin);
	}

	///@notice Change the minimum auction length. Only callable by the current admin.
	///@param _minLength New minimum auction length.
	function changeMinLength(uint256 _minLength) external onlyAdmin {
		emit AuctionMinimumChanged(minAuctionLength, _minLength);
		
		minAuctionLength = _minLength;
	}

	///@notice Change the maximum auction length.
	///@param _maxLength New maximum auction length.
	function changeMaxLength(uint256 _maxLength) external onlyAdmin {
		emit AuctionMaximumChanged(maxAuctionLength, _maxLength);
		
		maxAuctionLength = _maxLength;
	}
}