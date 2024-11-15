pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {REMPresale} from "../src/REMPresale.sol";
import {Errors} from "../src/libs/Errors.sol";
import {console} from "forge-std/console.sol";
import {ERC20Mock} from "../src/mocks/ERC20Mock.sol";
import {IREMPresale} from "../src/interfaces/IREMPresale.sol";
import {Errors} from "../src/libs/Errors.sol";

contract REMPresaleTest is Test {
    REMPresale public remPresale;
    ERC20Mock public saleToken;
    ERC20Mock public paymentToken;
    IREMPresale.Presale presale;

    address public admin = address(1);
    address public user1 = address(2);
    address public user2 = address(3);
    address public destinationWallet = address(4);
    address public vestingContract = address(5);

    address public constant NATIVE_TOKEN_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function setUp() public {
        console.log("Setting up contracts and initial state...");
        saleToken = new ERC20Mock(address(this), 18);
        paymentToken = new ERC20Mock(address(this), 18);
        remPresale = new REMPresale(address(saleToken), admin, vestingContract);

        vm.prank(admin);
        paymentToken.mint(user1, 1000 ether);
        paymentToken.mint(user2, 1000 ether);

        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);

        bool isAdmin = remPresale.hasRole(remPresale.DEFAULT_ADMIN_ROLE(), admin);
        console.log("Admin has DEFAULT_ADMIN_ROLE: ", isAdmin);

        console.log("Setup complete");
    }

    function testCreatePresale() public {
        vm.startPrank(admin);

        IREMPresale.Timing memory presaleTiming =
            IREMPresale.Timing({startTime: block.timestamp + 1 days, endTime: block.timestamp + 7 days});

        IREMPresale.VestingDetails memory vestingDetails = IREMPresale.VestingDetails({
            cliffDuration: 30 days,
            vestingDuration: 180 days,
            tgePercentage: 10,
            groupName: "Test Group"
        });

        remPresale.createPresale(
            presaleTiming, 1 ether, 100 ether, address(paymentToken), 18, destinationWallet, true, false, vestingDetails
        );

        // Get presale details
        (
            address saleToken_,
            IREMPresale.Tokens memory tokens,
            IREMPresale.Timing memory timing,
            uint256 price,
            address paymentToken_,
            uint256 baseDecimals,
            address destinationWallet_,
            IREMPresale.Config memory config,
            IREMPresale.VestingDetails memory vesting
        ) = remPresale.presales(1);

        // Verify presale details
        assertEq(saleToken_, address(saleToken));
        assertEq(tokens.tokensToSell, 100 ether);
        assertEq(tokens.inSale, 100 ether);
        assertEq(timing.startTime, block.timestamp + 1 days);
        assertEq(timing.endTime, block.timestamp + 7 days);
        assertEq(price, 1 ether);
        assertEq(paymentToken_, address(paymentToken));
        assertEq(baseDecimals, 18);
        assertEq(destinationWallet_, destinationWallet);
        assertTrue(config.whitelistingEnabled);
        assertFalse(config.vestingCall);
        assertEq(vesting.cliffDuration, 30 days);
        assertEq(vesting.vestingDuration, 180 days);
        assertEq(vesting.tgePercentage, 10);
        assertEq(vesting.groupName, "Test Group");
    }

    function testChangeSaleTimes() public {
        vm.prank(admin);

        IREMPresale.Timing memory presaleTiming =
            IREMPresale.Timing({startTime: block.timestamp + 1 days, endTime: block.timestamp + 8 days});

        IREMPresale.VestingDetails memory vestingDetails = IREMPresale.VestingDetails({
            cliffDuration: 30 days,
            vestingDuration: 180 days,
            tgePercentage: 10,
            groupName: "Test Group"
        });

        remPresale.createPresale(
            presaleTiming, 1 ether, 100 ether, address(paymentToken), 18, destinationWallet, true, false, vestingDetails
        );

        vm.prank(admin);
        remPresale.changeSaleTimes(1, block.timestamp + 2 days, block.timestamp + 9 days);

        (
            address saleToken_,
            IREMPresale.Tokens memory tokens,
            IREMPresale.Timing memory timing,
            uint256 price,
            address paymentToken_,
            uint256 baseDecimals,
            address destinationWallet_,
            IREMPresale.Config memory config,
            IREMPresale.VestingDetails memory vesting
        ) = remPresale.presales(1);

        assertEq(timing.startTime, block.timestamp + 2 days);
        assertEq(timing.endTime, block.timestamp + 9 days);
    }

    function testChangeSaleTokenAddress() public {
        vm.prank(admin);
        IREMPresale.Timing memory presaleTiming =
            IREMPresale.Timing({startTime: block.timestamp + 1 days, endTime: block.timestamp + 8 days});

        IREMPresale.VestingDetails memory vestingDetails = IREMPresale.VestingDetails({
            cliffDuration: 30 days,
            vestingDuration: 180 days,
            tgePercentage: 10,
            groupName: "Test Group"
        });

        remPresale.createPresale(
            presaleTiming, 1 ether, 100 ether, address(paymentToken), 18, destinationWallet, true, false, vestingDetails
        );

        address newSaleToken = address(new ERC20Mock(address(this), 18));
        vm.prank(admin);
        remPresale.changeSaleTokenAddress(1, newSaleToken);

        (
            address saleToken_,
            IREMPresale.Tokens memory tokens,
            IREMPresale.Timing memory timing,
            uint256 price,
            address paymentToken_,
            uint256 baseDecimals,
            address destinationWallet_,
            IREMPresale.Config memory config,
            IREMPresale.VestingDetails memory vesting
        ) = remPresale.presales(1);

        assertEq(saleToken_, newSaleToken);
    }

    function testChangePrice() public {
        vm.prank(admin);

        IREMPresale.Timing memory presaleTiming =
            IREMPresale.Timing({startTime: block.timestamp + 1 days, endTime: block.timestamp + 8 days});

        IREMPresale.VestingDetails memory vestingDetails = IREMPresale.VestingDetails({
            cliffDuration: 30 days,
            vestingDuration: 180 days,
            tgePercentage: 10,
            groupName: "Test Group"
        });

        remPresale.createPresale(
            presaleTiming, 1 ether, 100 ether, address(paymentToken), 18, destinationWallet, true, false, vestingDetails
        );

        vm.prank(admin);
        remPresale.changePrice(1, 2 ether);

        // Get presale details
        (
            address saleToken_,
            IREMPresale.Tokens memory tokens,
            IREMPresale.Timing memory timing,
            uint256 price,
            address paymentToken_,
            uint256 baseDecimals,
            address destinationWallet_,
            IREMPresale.Config memory config,
            IREMPresale.VestingDetails memory vesting
        ) = remPresale.presales(1);

        assertEq(price, 2 ether);
    }

    function testChangePaymentToken() public {
        vm.prank(admin);

        IREMPresale.Timing memory presaleTiming =
            IREMPresale.Timing({startTime: block.timestamp + 1 days, endTime: block.timestamp + 8 days});

        IREMPresale.VestingDetails memory vestingDetails = IREMPresale.VestingDetails({
            cliffDuration: 30 days,
            vestingDuration: 180 days,
            tgePercentage: 10,
            groupName: "Test Group"
        });

        remPresale.createPresale(
            presaleTiming, 1 ether, 100 ether, address(paymentToken), 18, destinationWallet, true, false, vestingDetails
        );

        address newPaymentToken = address(new ERC20Mock(address(this), 18));
        vm.prank(admin);
        remPresale.changePaymentToken(1, newPaymentToken);

        (
            address saleToken_,
            IREMPresale.Tokens memory tokens,
            IREMPresale.Timing memory timing,
            uint256 price,
            address paymentToken_,
            uint256 baseDecimals,
            address destinationWallet_,
            IREMPresale.Config memory config,
            IREMPresale.VestingDetails memory vesting
        ) = remPresale.presales(1);

        assertEq(paymentToken_, newPaymentToken);
    }

    function testUpdateWhitelistingStatus() public {
        vm.prank(admin);

        IREMPresale.Timing memory presaleTiming =
            IREMPresale.Timing({startTime: block.timestamp + 1 days, endTime: block.timestamp + 8 days});

        IREMPresale.VestingDetails memory vestingDetails = IREMPresale.VestingDetails({
            cliffDuration: 30 days,
            vestingDuration: 180 days,
            tgePercentage: 10,
            groupName: "Test Group"
        });

        remPresale.createPresale(
            presaleTiming, 1 ether, 100 ether, address(paymentToken), 18, destinationWallet, true, false, vestingDetails
        );

        vm.prank(admin);
        remPresale.updateWhitelistingStatus(1, false);

        (
            address saleToken_,
            IREMPresale.Tokens memory tokens,
            IREMPresale.Timing memory timing,
            uint256 price,
            address paymentToken_,
            uint256 baseDecimals,
            address destinationWallet_,
            IREMPresale.Config memory config,
            IREMPresale.VestingDetails memory vesting
        ) = remPresale.presales(1);

        assertFalse(config.whitelistingEnabled);
    }

    function testBatchUpdateWhitelist() public {
        vm.prank(admin);

        IREMPresale.Timing memory presaleTiming =
            IREMPresale.Timing({startTime: block.timestamp + 1 days, endTime: block.timestamp + 8 days});

        IREMPresale.VestingDetails memory vestingDetails = IREMPresale.VestingDetails({
            cliffDuration: 30 days,
            vestingDuration: 180 days,
            tgePercentage: 10,
            groupName: "Test Group"
        });

        remPresale.createPresale(
            presaleTiming, 1 ether, 100 ether, address(paymentToken), 18, destinationWallet, true, false, vestingDetails
        );

        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2;

        vm.prank(admin);
        remPresale.batchUpdateWhitelist(1, users, true);

        assertTrue(remPresale.whitelist(1, user1));
        assertTrue(remPresale.whitelist(1, user2));
    }

    function testBuy() public {
        vm.prank(admin);

        IREMPresale.Timing memory presaleTiming =
            IREMPresale.Timing({startTime: block.timestamp + 1, endTime: block.timestamp + 7 days});

        IREMPresale.VestingDetails memory vestingDetails = IREMPresale.VestingDetails({
            cliffDuration: 30 days,
            vestingDuration: 180 days,
            tgePercentage: 10,
            groupName: "Test Group"
        });

        remPresale.createPresale(
            presaleTiming,
            1 ether,
            100 ether,
            address(paymentToken),
            18,
            destinationWallet,
            false,
            false,
            vestingDetails
        );

        vm.warp(block.timestamp + 2);

        vm.prank(user1);
        paymentToken.approve(address(remPresale), 10 ether);

        vm.prank(user1);
        remPresale.buy(1, 10 ether);

        (uint256 amount,) = remPresale.getUserPurchase(1, user1);
        assertEq(amount, 10 ether);
        assertEq(paymentToken.balanceOf(destinationWallet), 10 ether);
    }

    function testBuyWithNativeToken() public {
        vm.prank(admin);
        IREMPresale.Timing memory presaleTiming =
            IREMPresale.Timing({startTime: block.timestamp + 1, endTime: block.timestamp + 7 days});

        IREMPresale.VestingDetails memory vestingDetails = IREMPresale.VestingDetails({
            cliffDuration: 30 days,
            vestingDuration: 180 days,
            tgePercentage: 10,
            groupName: "Test Group"
        });

        remPresale.createPresale(
            presaleTiming,
            1 ether,
            100 ether,
            address(paymentToken),
            18,
            destinationWallet,
            false,
            false,
            vestingDetails
        );
        vm.warp(block.timestamp + 2);
        uint256 initialBalance = destinationWallet.balance;

        vm.prank(user1);
        remPresale.buy{value: 10 ether}(1, 10 ether);

        (uint256 amount,) = remPresale.getUserPurchase(1, user1);
        assertEq(amount, 10 ether);
        assertEq(destinationWallet.balance, initialBalance + 10 ether);
    }

    function testTogglePausePresale() public {
        vm.prank(admin);
        IREMPresale.Timing memory presaleTiming =
            IREMPresale.Timing({startTime: block.timestamp + 1, endTime: block.timestamp + 7 days});

        IREMPresale.VestingDetails memory vestingDetails = IREMPresale.VestingDetails({
            cliffDuration: 30 days,
            vestingDuration: 180 days,
            tgePercentage: 10,
            groupName: "Test Group"
        });

        remPresale.createPresale(
            presaleTiming,
            1 ether,
            100 ether,
            address(paymentToken),
            18,
            destinationWallet,
            false,
            false,
            vestingDetails
        );
        vm.warp(block.timestamp + 2);
        vm.prank(admin);
        remPresale.togglePausePresale(1, true);

        assertTrue(remPresale.pausedPresales(1));

        vm.prank(admin);
        remPresale.togglePausePresale(1, false);

        assertFalse(remPresale.pausedPresales(1));
    }

    function testBuyFailsWhenPresalePaused() public {
        vm.prank(admin);
        IREMPresale.Timing memory presaleTiming =
            IREMPresale.Timing({startTime: block.timestamp + 1, endTime: block.timestamp + 7 days});

        IREMPresale.VestingDetails memory vestingDetails = IREMPresale.VestingDetails({
            cliffDuration: 30 days,
            vestingDuration: 180 days,
            tgePercentage: 10,
            groupName: "Test Group"
        });

        remPresale.createPresale(
            presaleTiming,
            1 ether,
            100 ether,
            address(paymentToken),
            18,
            destinationWallet,
            false,
            false,
            vestingDetails
        );
        vm.warp(block.timestamp + 2);
        vm.prank(admin);
        remPresale.togglePausePresale(1, true);

        vm.prank(user1);
        paymentToken.approve(address(remPresale), 10 ether);

        vm.prank(user1);
        vm.expectRevert(Errors.PresalePaused.selector);
        remPresale.buy(1, 10 ether);
    }

    function testBuyFailsWhenNotWhitelisted() public {
        vm.prank(admin);
        IREMPresale.Timing memory presaleTiming =
            IREMPresale.Timing({startTime: block.timestamp + 1, endTime: block.timestamp + 7 days});

        IREMPresale.VestingDetails memory vestingDetails = IREMPresale.VestingDetails({
            cliffDuration: 30 days,
            vestingDuration: 180 days,
            tgePercentage: 10,
            groupName: "Test Group"
        });

        remPresale.createPresale(
            presaleTiming,
            1 ether,
            100 ether,
            address(paymentToken),
            18,
            destinationWallet,
            false,
            false,
            vestingDetails
        );
        vm.warp(block.timestamp + 2);
        vm.prank(user1);
        paymentToken.approve(address(remPresale), 10 ether);

        vm.prank(user1);
        vm.expectRevert();
        remPresale.buy(1, 10 ether);
    }

    function testBuyFailsWhenInsufficientAllowance() public {
        vm.prank(admin);
        IREMPresale.Timing memory presaleTiming =
            IREMPresale.Timing({startTime: block.timestamp + 1, endTime: block.timestamp + 7 days});

        IREMPresale.VestingDetails memory vestingDetails = IREMPresale.VestingDetails({
            cliffDuration: 30 days,
            vestingDuration: 180 days,
            tgePercentage: 10,
            groupName: "Test Group"
        });

        remPresale.createPresale(
            presaleTiming,
            1 ether,
            100 ether,
            address(paymentToken),
            18,
            destinationWallet,
            false,
            false,
            vestingDetails
        );
        vm.warp(block.timestamp + 2);
        vm.prank(user1);
        paymentToken.approve(address(remPresale), 5 ether);

        vm.prank(user1);
        vm.expectRevert(Errors.InsufficientAllowance.selector);
        remPresale.buy(1, 10 ether);
    }

    function testBuyFailsWhenInsufficientPayment() public {
        vm.prank(admin);
        IREMPresale.Timing memory presaleTiming =
            IREMPresale.Timing({startTime: block.timestamp + 1, endTime: block.timestamp + 7 days});

        IREMPresale.VestingDetails memory vestingDetails = IREMPresale.VestingDetails({
            cliffDuration: 30 days,
            vestingDuration: 180 days,
            tgePercentage: 10,
            groupName: "Test Group"
        });

        remPresale.createPresale(
            presaleTiming,
            1 ether,
            100 ether,
            address(paymentToken),
            18,
            destinationWallet,
            false,
            false,
            vestingDetails
        );
        vm.warp(block.timestamp + 2);
        vm.prank(user1);
        vm.expectRevert(Errors.InsufficientPayment.selector);
        remPresale.buy{value: 5 ether}(1, 10 ether);
    }
}
