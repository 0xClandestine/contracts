// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {IdNFT} from "../src/interfaces/IdNFT.sol";
import {dNFT} from "../src/core/dNFT.sol";
import "../src/core/Dyad.sol";
import "../src/core/Pool.sol";

contract Deployment is Script {
  function deploy(address oracle,
                  uint depositMinimum,
                  uint minCollaterizationRatio, 
                  uint maxSupply,
                  address[] memory insiders) public returns (address, address, address) {
    vm.startBroadcast();
    DYAD dyad = new DYAD();

    dNFT _dnft = new dNFT(address(dyad),
                          depositMinimum,
                          minCollaterizationRatio,
                          maxSupply,
                          oracle,
                          insiders);

    IdNFT dnft = IdNFT(address(_dnft));

    Pool pool = new Pool(address(dnft), address(dyad), oracle);

    dyad.transferOwnership(address(dnft));

    vm.stopBroadcast();

    return (address(dnft), address(pool), address(dyad));
  }
}
