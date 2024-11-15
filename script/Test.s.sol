// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {ERC20Mock} from "../src/mocks/ERC20Mock.sol";
import {REMVesting} from "../src/REMVesting.sol";
import {REMPresale} from "../src/REMPresale.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {console} from "forge-std/console.sol";

contract Test is Script {
    // Define wallet addresses
    address constant WALLET_1 = 0x3F8c9Bf8C84eC8616AB06Ee8aC4f331D71ACFfc4;
    address constant WALLET_2 = 0xd92a28cbE5e459B436707AD78136E8F3186ed86f;
    address constant WALLET_3 = 0x113f88356685fb773320fA9FE6054d34d8730204;
    address constant ADMIN = 0xAD09555B8132B3007ff17AC36Ba1760a5a6B1C10;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Deploy SaleToken (MockToken with 18 decimals)
        ERC20Mock saleToken = new ERC20Mock(ADMIN, 18);
        console.log("SaleToken deployed at:", address(saleToken));

        // Step 2: Deploy PaymentToken (USDC with 6 decimals)
        ERC20Mock paymentToken = new ERC20Mock(ADMIN, 6);
        paymentToken.mint(WALLET_1, 10000 * 10 ** 6);
        paymentToken.mint(WALLET_2, 10000 * 10 ** 6);
        paymentToken.mint(WALLET_3, 10000 * 10 ** 6);
        console.log("PaymentToken (USDC) deployed at:", address(paymentToken));

        // Step 3: Deploy REMVesting contract
        REMVesting vestingContract = new REMVesting(
            ADMIN, // Admin
            ADMIN, // Manager
            WALLET_1, // Recovery address
            address(saleToken) // Sale token address
        );
        console.log("REMVesting contract deployed at:", address(vestingContract));

        // Step 4: Deploy REMPresale contract
        REMPresale presaleContract = new REMPresale(
            address(saleToken), // Sale token address
            ADMIN, // Admin
            address(vestingContract) // Vesting contract address
        );
        console.log("REMPresale contract deployed at:", address(presaleContract));

        // Step 5: Grant the presale contract the MANAGER_ROLE in the vesting contract
        bytes32 MANAGER_ROLE = vestingContract.MANAGER_ROLE();
        vestingContract.grantRole(MANAGER_ROLE, address(presaleContract));
        console.log("Granted MANAGER_ROLE to the presale contract in the vesting contract");

        // Step 6: Assign the roles to WALLET_1, WALLET_2, WALLET_3 as admins and managers
        vestingContract.grantRole(vestingContract.DEFAULT_ADMIN_ROLE(), WALLET_1);
        vestingContract.grantRole(vestingContract.DEFAULT_ADMIN_ROLE(), WALLET_2);
        vestingContract.grantRole(vestingContract.DEFAULT_ADMIN_ROLE(), WALLET_3);
        vestingContract.grantRole(MANAGER_ROLE, WALLET_1);
        vestingContract.grantRole(MANAGER_ROLE, WALLET_2);
        vestingContract.grantRole(MANAGER_ROLE, WALLET_3);
        console.log("Roles assigned to WALLET_1, WALLET_2, WALLET_3 in the vesting contract");

        // Same roles for presale contract
        presaleContract.grantRole(presaleContract.DEFAULT_ADMIN_ROLE(), WALLET_1);
        presaleContract.grantRole(presaleContract.DEFAULT_ADMIN_ROLE(), WALLET_2);
        presaleContract.grantRole(presaleContract.DEFAULT_ADMIN_ROLE(), WALLET_3);
        console.log("Roles assigned to WALLET_1, WALLET_2, WALLET_3 in the presale contract");

        vm.stopBroadcast();
    }
}
