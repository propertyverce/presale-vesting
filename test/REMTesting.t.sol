pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {REMVesting} from "../src/REMVesting.sol";
import {Errors} from "../src/libs/Errors.sol";
import {console} from "forge-std/console.sol";
import {ERC20Mock} from "../src/mocks/ERC20Mock.sol";

contract REMVestingTest is Test {
    REMVesting public remVesting;
    ERC20Mock public token;

    address public admin = address(1);
    address public manager = address(2);
    address public user1 = address(3);
    address public user2 = address(4);
    address public recoveryAddress = address(5);

    uint256 public tgePercentage = 1000; // 10%
    uint256 public initialBalance = 1000 ether;

    function setUp() public {
        console.log("Setting up contracts and initial state...");
        token = new ERC20Mock(address(this), 18);
        remVesting = new REMVesting(admin, manager, recoveryAddress, address(token));

        vm.prank(admin);
        token.mint(address(this), initialBalance);
        token.mint(admin, initialBalance);

        vm.prank(admin);
        token.approve(address(remVesting), initialBalance);

        bool isAdmin = remVesting.hasRole(remVesting.DEFAULT_ADMIN_ROLE(), admin);
        console.log("Admin has DEFAULT_ADMIN_ROLE: ", isAdmin);

        console.log("Setup complete");
    }

    function testCreateVestingSchedule() public {
        vm.prank(manager);
        remVesting.createVestingSchedule(
            user1,
            100 ether,
            90 days, // Duration: 90 days cliff period
            365 days, // Duration: 365 days vesting period
            tgePercentage,
            "TEAM"
        );

        REMVesting.UserVestingInfo memory vestingInfo = remVesting.getVestingInfoByBeneficiary(user1);

        assertEq(vestingInfo.totalAmount, 100 ether);
        assertEq(vestingInfo.vestingAmount, 90 ether);
    }

    function testStartContract() public {
        vm.prank(manager);
        remVesting.createVestingSchedule(
            user1,
            100 ether,
            90 days, // Duration: 90 days cliff period
            365 days, // Duration: 365 days vesting period
            tgePercentage,
            "TEAM"
        );

        vm.prank(admin);
        remVesting.startContract();

        assertTrue(remVesting.tgeUnlocked());
    }

    function testClaimTGE() public {
        vm.prank(manager);
        remVesting.createVestingSchedule(
            user1,
            100 ether,
            90 days, // Duration: 90 days cliff period
            365 days, // Duration: 365 days vesting period
            tgePercentage,
            "TEAM"
        );

        vm.prank(admin);
        remVesting.startContract();

        uint256 user1InitialBalance = token.balanceOf(user1);
        vm.prank(user1);
        remVesting.claimTGE();

        uint256 tgeAmount = (100 ether * tgePercentage) / remVesting.DENOMINATOR();
        assertEq(token.balanceOf(user1), user1InitialBalance + tgeAmount);
    }

    function testRelease() public {
        vm.prank(manager);
        remVesting.createVestingSchedule(
            user1,
            100 ether,
            90 days, // Duration: 90 days cliff period
            365 days, // Duration: 365 days vesting period
            tgePercentage,
            "TEAM"
        );

        vm.prank(admin);
        remVesting.startContract();

        vm.warp(block.timestamp + 180 days);

        uint256 user1InitialBalance = token.balanceOf(user1);
        uint256 releasableAmount = remVesting.releasable(user1);
        vm.prank(user1);
        remVesting.release(releasableAmount);

        assertEq(token.balanceOf(user1), user1InitialBalance + releasableAmount);
    }

    function testPauseAndUnpause() public {
        vm.prank(manager);
        remVesting.createVestingSchedule(
            user1,
            100 ether,
            90 days, // Duration: 90 days cliff period
            365 days, // Duration: 365 days vesting period
            tgePercentage,
            "TEAM"
        );

        vm.prank(admin);
        remVesting.startContract();

        vm.warp(block.timestamp + 180 days);

        uint256 user1InitialBalance = token.balanceOf(user1);
        uint256 releasableAmount = remVesting.releasable(user1);
        vm.prank(admin);
        remVesting.pause();

        vm.prank(user1);
        vm.expectRevert();
        remVesting.release(releasableAmount);

        vm.prank(admin);
        remVesting.unpause();

        vm.prank(user1);
        remVesting.release(releasableAmount);
    }

    function testInvalidAmountReverts() public {
        vm.prank(manager);
        remVesting.createVestingSchedule(
            user1,
            100 ether,
            90 days, // Duration: 90 days cliff period
            365 days, // Duration: 365 days vesting period
            tgePercentage,
            "TEAM"
        );

        vm.prank(admin);
        remVesting.startContract();

        vm.warp(block.timestamp + 180 days);

        vm.prank(user1);
        vm.expectRevert(Errors.InvalidAmount.selector);
        remVesting.release(0);

        vm.prank(user1);
        vm.expectRevert(Errors.InvalidAmount.selector);
        remVesting.release(200 ether);
    }

    function testContractNotStartedReverts() public {
        vm.prank(manager);
        remVesting.createVestingSchedule(
            user1,
            100 ether,
            90 days, // Duration: 90 days cliff period
            365 days, // Duration: 365 days vesting period
            tgePercentage,
            "TEAM"
        );

        vm.prank(user1);
        vm.expectRevert(Errors.ContractNotStarted.selector);
        remVesting.claimTGE();

        vm.prank(user1);
        vm.expectRevert(Errors.ContractNotStarted.selector);
        remVesting.release(10 ether);
    }

    function testAddressZeroProvidedReverts() public {
        vm.expectRevert(Errors.AddressZeroProvided.selector);
        new REMVesting(address(0), address(0), address(token), address(token));

        vm.expectRevert(Errors.AddressZeroProvided.selector);
        new REMVesting(admin, address(0), address(0), address(token));
    }

    function testAlreadyUnlockedReverts() public {
        vm.prank(manager);
        remVesting.createVestingSchedule(
            user1,
            100 ether,
            90 days, // Duration: 90 days cliff period
            365 days, // Duration: 365 days vesting period
            tgePercentage,
            "TEAM"
        );

        vm.prank(admin);
        remVesting.startContract();

        vm.prank(admin);
        vm.expectRevert(Errors.AlreadyUnlocked.selector);
        remVesting.startContract();
    }

    /* function testMultipleUsersVesting() public {
        vm.prank(manager);
        remVesting.createVestingSchedule(user1, 100 ether, block.timestamp, block.timestamp + 365 days, "TEAM");
        remVesting.createVestingSchedule(user2, 200 ether, block.timestamp, block.timestamp + 730 days, "ADVISOR");

        vm.prank(admin);
        remVesting.startContract();

        uint256 user1InitialBalance = token.balanceOf(user1);

        vm.prank(user1);
        remVesting.claimTGE();

        uint256 tgeAmount = (100 ether * tgePercentage) / remVesting.DENOMINATOR();
        assertEq(token.balanceOf(user1), user1InitialBalance + tgeAmount);  

        vm.warp(block.timestamp + 180 days);
        
        uint256 user1Releasable = remVesting.releasable(user1);
        uint256 user2Releasable = remVesting.releasable(user2);

        assertGt(user1Releasable, 0);
        assertGt(user2Releasable, 0);
        assertGt(user1Releasable, user2Releasable);
    } */

    function testVestingAfterCliff() public {
        uint256 cliffPeriod = 90 days;
        vm.prank(manager);
        remVesting.createVestingSchedule(
            user1,
            100 ether,
            90 days, // Duration: 90 days cliff period
            365 days, // Duration: 365 days vesting period
            tgePercentage,
            "TEAM"
        );

        vm.prank(admin);
        remVesting.startContract();

        vm.warp(block.timestamp + cliffPeriod - 1);
        assertEq(remVesting.releasable(user1), 0);

        vm.warp(block.timestamp + 10 days);
        assertGt(remVesting.releasable(user1), 0);
    }

    function testStartContractAlreadyStartedReverts() public {
        vm.prank(manager);
        remVesting.createVestingSchedule(
            user1,
            100 ether,
            90 days, // Duration: 90 days cliff period
            365 days, // Duration: 365 days vesting period
            tgePercentage,
            "TEAM"
        );

        vm.prank(admin);
        remVesting.startContract();

        vm.prank(admin);
        vm.expectRevert(Errors.AlreadyUnlocked.selector);
        remVesting.startContract();
    }

    function testPartialRelease() public {
        vm.prank(manager);
        remVesting.createVestingSchedule(
            user1,
            100 ether,
            90 days, // Duration: 90 days cliff period
            365 days, // Duration: 365 days vesting period
            tgePercentage,
            "TEAM"
        );

        vm.prank(admin);
        remVesting.startContract();

        vm.warp(block.timestamp + 180 days);

        uint256 releasableAmount = remVesting.releasable(user1);
        uint256 partialAmount = releasableAmount / 2;

        vm.prank(user1);
        remVesting.release(partialAmount);

        assertEq(remVesting.releasable(user1), releasableAmount - partialAmount);
    }

    function testMultipleReleases() public {
        vm.prank(manager);
        remVesting.createVestingSchedule(
            user1,
            100 ether,
            90 days, // Duration: 90 days cliff period
            365 days, // Duration: 365 days vesting period
            tgePercentage,
            "TEAM"
        );

        vm.prank(admin);
        remVesting.startContract();

        for (uint256 i = 1; i <= 4; i++) {
            vm.warp(block.timestamp + 90 days);
            uint256 releasableAmount = remVesting.releasable(user1);
            vm.prank(user1);
            remVesting.release(releasableAmount);
        }

        assertLt(remVesting.releasable(user1), 1 ether); // Should be very close to 0, accounting for rounding
    }

    function testEmergencyWithdraw() public {
        vm.prank(manager);
        remVesting.createVestingSchedule(
            user1,
            100 ether,
            90 days, // Duration: 90 days cliff period
            365 days, // Duration: 365 days vesting period
            tgePercentage,
            "TEAM"
        );

        vm.prank(admin);
        remVesting.startContract();

        uint256 tokenInitialBalance = token.balanceOf(address(remVesting));
        uint256 userTokenInitialBalance = token.balanceOf(admin);
        vm.prank(admin);
        remVesting.emergencyWithdraw(admin, address(token));

        assertEq(token.balanceOf(address(remVesting)), 0);
        assertEq(token.balanceOf(admin), tokenInitialBalance + userTokenInitialBalance);
    }

    function testOnlyAdminCanEmergencyWithdraw() public {
        vm.prank(manager);
        vm.expectRevert();
        remVesting.emergencyWithdraw(manager, address(token));
    }

    function testVestingInfoUpdatesCorrectly() public {
        vm.prank(manager);
        remVesting.createVestingSchedule(
            user1,
            100 ether,
            90 days, // Duration: 90 days cliff period
            365 days, // Duration: 365 days vesting period
            tgePercentage,
            "TEAM"
        );

        vm.prank(admin);
        remVesting.startContract();

        vm.prank(user1);
        remVesting.claimTGE();

        REMVesting.UserVestingInfo memory vestingInfo = remVesting.getVestingInfoByBeneficiary(user1);

        assertEq(vestingInfo.vestingAmount, 90 ether);
        assertEq(vestingInfo.totalAmount, 100 ether);
        assertEq(vestingInfo.vestingReleased, 0);
        assertTrue(vestingInfo.tgeClaimed);

        vm.warp(block.timestamp + 180 days);
        uint256 releasableAmount = remVesting.releasable(user1);
        vm.prank(user1);
        remVesting.release(releasableAmount);

        REMVesting.UserVestingInfo memory newVestingInfo = remVesting.getVestingInfoByBeneficiary(user1);
        assertEq(newVestingInfo.vestingReleased, releasableAmount);
    }
}
