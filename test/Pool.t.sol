// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/dyad.sol";
import "../src/dNFT.sol";
import "../src/pool.sol";

contract PoolTest is Test {
  DYAD public dyad;
  Pool public pool;
  dNFT public dnft;

  function setUp() public {
    dyad = new DYAD();
    dnft = new dNFT(address(dyad));
    pool = new Pool(address(dnft), address(dyad));

    dyad.setMinter(address(pool));
    dnft.setPool(address(pool));
  }

  function overwriteLastEthPrice(uint newPrice) public {
    vm.store(address(pool), 0, bytes32(newPrice));
  }

  function testSync() public {
    pool.sync();
    // sanity check
    assertTrue(pool.lastEthPrice() > 0);

    // mint some dyad
    dnft.mintNft{value: 5 ether}(address(this));
    dnft.mintDyad{value: 1 ether}(0); 

    overwriteLastEthPrice(130000000000);
    console.log("testSync");
    pool.sync();
  }
}
