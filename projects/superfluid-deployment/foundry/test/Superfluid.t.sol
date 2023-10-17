// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Test, console2 } from "forge-std/Test.sol";

import { ERC1820RegistryCompiled } from
    "@superfluid-finance/ethereum-contracts/contracts/libs/ERC1820RegistryCompiled.sol";
import {
    IPureSuperToken,
    ISETH,
    SuperfluidFrameworkDeployer,
    SuperToken,
    TestToken
} from "@superfluid-finance/ethereum-contracts/contracts/utils/SuperfluidFrameworkDeployer.sol";

contract SuperfluidTest is Test {
    SuperfluidFrameworkDeployer.Framework internal sf;
    SuperfluidFrameworkDeployer internal deployer;

    uint8 public constant decimals = 18;

    function setUp() public {
        vm.etch(ERC1820RegistryCompiled.at, ERC1820RegistryCompiled.bin);

        deployer = new SuperfluidFrameworkDeployer();
        deployer.deployTestFramework();
        sf = deployer.getFramework();
    }

    function testDeployWrapperSuperToken() public {
        (TestToken underlyingToken, SuperToken superToken) =
            deployer.deployWrapperSuperToken("TestToken", "TEST", decimals, type(uint256).max);

        assertEq(address(underlyingToken), address(superToken.getUnderlyingToken()), "underlying token incorrect");
        assertEq(string.concat("Super ", underlyingToken.symbol()), superToken.name(), "name incorrect");
        assertEq(string.concat(underlyingToken.symbol(), "x"), superToken.symbol(), "symbol incorrect");
        assertEq(underlyingToken.decimals(), decimals, "decimals incorrect");
        assertEq(superToken.getAdmin(), address(0), "admin incorrect");
    }

    function testDeployNativeAssetSuperToken() public {
        string memory symbol = "ETHx";

        ISETH nativeAssetSuperToken = deployer.deployNativeAssetSuperToken("Super ETHx", symbol);

        assertEq(address(nativeAssetSuperToken.getUnderlyingToken()), address(0), "underlying token incorrect");
        assertEq(
            nativeAssetSuperToken.name(), name, "name incorrect"
        );
        assertEq(nativeAssetSuperToken.symbol(), symbol, "symbol incorrect");
        assertEq(nativeAssetSuperToken.getAdmin(), address(0), "admin incorrect");
    }

    function testDeployPureSuperToken() public {
        string memory name = "Super MRx";
        string memory symbol = "MRx";

        IPureSuperToken pureSuperToken = deployer.deployPureSuperToken("Super MRx", "MRx", uint256(type(int256).max));

        assertEq(address(0), address(pureSuperToken.getUnderlyingToken()), "underlying token incorrect");
        assertEq(pureSuperToken.name(), name, "name incorrect");
        assertEq(pureSuperToken.symbol(), symbol, "symbol incorrect");
        assertEq(pureSuperToken.decimals(), decimals, "decimals incorrect");
        assertEq(pureSuperToken.getAdmin(), address(0), "admin incorrect");
    }
}
