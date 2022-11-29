// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/dyad.sol";
import "../src/pool.sol";
import "ds-test/test.sol";
import {IdNFT} from "../src/interfaces/IdNFT.sol";
import {dNFT} from "../src/dNFT.sol";
import {PoolLibrary} from "../src/PoolLibrary.sol";
import {OracleMock} from "./Oracle.t.sol";

interface CheatCodes {
   // Gets address for a given private key, (privateKey) => (address)
   function addr(uint256) external returns (address);
}

// reproduce eikes equations
// https://docs.google.com/spreadsheets/d/1pegDYo8hrOQZ7yZY428F_aQ_mCvK0d701mygZy-P04o/edit#gid=0
// There are many hard coded values here that are based on the equations in the 
// google sheet.
contract PoolTest is Test {
  using stdStorage for StdStorage;

  DYAD public dyad;
  Pool public pool;
  IdNFT public dnft;
  OracleMock public oracle;

  CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

  function setUp() public {
    oracle = new OracleMock();
    dyad = new DYAD();

    // init dNFT contract
    dNFT _dnft = new dNFT(address(dyad), false);
    dnft = IdNFT(address(_dnft));

    pool = new Pool(address(dnft), address(dyad), address(oracle));

    dyad.setMinter(address(pool));
    dnft.setPool(address(pool));

    // set oracle price
    vm.store(address(oracle), bytes32(uint(0)), bytes32(uint(95000000))); 
    // set DEPOSIT_MINIMUM to something super low, so we do not run into the $5k limit
    stdstore.target(address(dnft)).sig("DEPOSIT_MINIMUM()").checked_write(77);

    // mint 10 nfts with a specific deposit to re-create the equations
    for (uint i = 0; i < 10; i++) {
      dnft.mintNft{value: 10106 wei}(cheats.addr(i+1)); // i+1 to avoid 0x0 address
    }

    setNfts();

    vm.store(address(pool), bytes32(uint(0)), bytes32(uint(100000000))); // lastEthPrice
    stdstore.target(address(dnft)).sig("MIN_XP()").checked_write(1079); // min xp
    stdstore.target(address(dnft)).sig("MAX_XP()").checked_write(8000); // max xp
  }

  // needed, so we can receive eth transfers
  receive() external payable {}

  // set withdrawn, deposit, xp
  // NOTE: I get a slot error for isClaimable so we do not set it here and 
  // leave it as it is. this seems to be broken for bool rn, see:
  // https://github.com/foundry-rs/forge-std/pull/103
  function overwriteNft(uint id, uint xp, uint deposit, uint withdrawn) public {
    IdNFT.Nft memory nft = dnft.idToNft(id);
    nft.withdrawn = withdrawn; nft.deposit = int(deposit); nft.xp = xp;

    stdstore.target(address(dnft)).sig("idToNft(uint256)").with_key(id)
      .depth(0).checked_write(nft.withdrawn);
    stdstore.target(address(dnft)).sig("idToNft(uint256)").with_key(id)
      .depth(1).checked_write(uint(nft.deposit));
    stdstore.target(address(dnft)).sig("idToNft(uint256)").with_key(id)
      .depth(2).checked_write(nft.xp);
    // stdstore.target(address(dnft)).sig("idToNft(uint256)").with_key(id)
    //   .depth(3).checked_write(true);
  }

  function setNfts() internal {
    // overwrite id, xp, deposit, withdrawn for each nft to the hard-coded
    // values in the google sheet
    overwriteNft(0, 2161, 146,  3920 );
    overwriteNft(1, 7588, 4616, 7496 );
    overwriteNft(2, 3892, 2731, 10644);
    overwriteNft(3, 3350, 4515, 2929 );
    overwriteNft(4, 3012, 2086, 3149 );
    overwriteNft(5, 5496, 7241, 7127 );
    overwriteNft(6, 8000, 8197, 7548 );
    overwriteNft(7, 7000, 5873, 9359 );
    overwriteNft(8, 3435, 1753, 4427 );
    overwriteNft(9, 1079, 2002, 244  );
  }

  // check that the nft deposit values are equal to each other
  function assertDeposits(int16[6] memory deposits) internal {
    for (uint i = 0; i < deposits.length; i++) {
      assertTrue(dnft.idToNft(i).deposit == deposits[i]);
    }
  }

  function setupBurn() public returns (uint){
    // change new oracle price to something lower so we trigger the burn
    vm.store(address(oracle), bytes32(uint(0)), bytes32(uint(95000000))); 
    uint totalSupplyBefore = dyad.totalSupply();
    uint dyadDelta = pool.sync();
    // there should be less dyad now after the sync
    assertTrue(totalSupplyBefore > dyad.totalSupply());
    return dyadDelta;
  }

  function testSyncBurn() public {
    uint dyadDelta = setupBurn();
    assertEq(dyadDelta, 4800);

    // check deposits after newly burned dyad. SOME ROUNDING ERRORS!
    assertDeposits([-135, 4365, 1805, 4000, 1724, 6250]);
  }

  function testClaim() public {
    setupBurn();

    // as we can see from the `testSyncBurn` above, the first nft deposit
    // is negative (-135), which makes it claimable by others.

    // this is not enough ether to claim the nft
    vm.expectRevert();
    pool.claim{value: 1   wei}(0, address(this));

    // 1 ether is enough
    // IMPORTANT: this test will only pass while the eth price is above $135.
    uint id = pool.claim{value: 1 ether}(0, address(this));

    // lets check that all the metadata moved from the burned nft to the newly minted one
    assertEq(dnft.idToNft(0).xp,        dnft.idToNft(id).xp);
    assertEq(dnft.idToNft(0).withdrawn, dnft.idToNft(id).withdrawn);

    // dnft 1 has a positive deposit, and therfore is not claimable
    vm.expectRevert();
    pool.claim{value: 1 ether}(1, address(this));
  }

  function testSyncMint() public {
    // change new oracle price to something higher so we trigger the mint
    vm.store(address(oracle), bytes32(uint(0)), bytes32(uint(110000000))); 
    uint totalSupplyBefore = dyad.totalSupply();
    uint dyadDelta = pool.sync();
    assertEq(dyadDelta, 9600);
    // there should be more dyad now after the sync
    assertTrue(totalSupplyBefore < dyad.totalSupply());

    // check deposits after newly minted dyad. SOME ROUNDING ERRORS!
    // why do we cast the first argument? Good question. This forces
    // the compiler to create a int16 array. Is there a better way?
    assertDeposits([int16(187), 6592, 2966, 5213, 2544, 7833]);
  }

  function testSyncLiquidation() public {
    // we are going to set the oracle price to something super low,
    // that will trigger the liquidation
    vm.store(address(oracle), bytes32(uint(0)), bytes32(uint(10000000))); 

    pool.sync();

    // nft 0 is now liquidated, lets claim it!
    pool.claim{value: 5 ether}(0, address(this));
  }
}
