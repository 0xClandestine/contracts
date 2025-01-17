// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

library PoolLibrary {
  // get amount in basis points from x.
  // EXAMPLE:
  // x = 10000000, basisPoints = 10  (0.1%) = 1000
  // x = 10000000, basisPoints = 200 (2.0%) = 200000
  function percentageOf(uint x, uint basisPoints) internal pure returns (uint) {
    // NOTE: if x*basisPoints < 10_000 -> returns 0
    return x*basisPoints/10000;
  }

  function getXpMulti(uint xp) internal pure returns (uint) {
    // xp is like an index which maps exactly to one value in the table. That is why
    // xp must be uint and between 0 and 100.
    require(xp >= 0 && xp <= 100, "PoolLibrary: xp out of range (0 <= xp <= 100)");

    // why 61?, because:
    // the first 61 values in the table are all 50, which means we do not need 
    // to store them in the table, but can do this compression.
    // But we need to subtract 61 in the else statement to get the correct lookup.
    if (xp < 61) {
      return 50;
    } else {
      uint8[40] memory XP_TABLE = [51,  51,  51,  51,  52,  53,  53,  54,  55,
                                   57,  58,  60,  63,  66,  69,  74,  79,  85,
                                   92,  99,  108, 118, 128, 139, 150, 160, 171,
                                   181, 191, 200, 207, 214, 220, 225, 230, 233,
                                   236, 239, 241, 242];
      return XP_TABLE[xp - 61]; 
    }
  }
}
