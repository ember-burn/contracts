// pragma solidity >=0.8.10;

// import "forge-std/Test.sol";
// import "../src/Vault.sol";
// import "../src/VaultFactory.sol";

// contract VaultTest is Test {
// 	VaultFactory public factory;
// 	Vault public vault;
	
// 	function setUp() public {
// 		factory = new VaultFactory(3 days, 50 days, address(this));	
// 	}

// 	function testVaultCreation() public {
// 		factory.createVault(
// 			3,
//        		block.timestamp + 10 days,
//         	block.timestamp + 20 days,
//         	10 ether,
// 			1000,
// 			address(0),
// 			1,
// 			address(this),
// 			'SYMB',
// 			'Test',
// 			bytes32(0)
// 		);
// 	}

	
// }