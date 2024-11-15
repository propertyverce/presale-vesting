// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IREMPresale} from "./interfaces/IREMPresale.sol";
import {Errors} from "./libs/Errors.sol";
import {IREMVesting} from "./interfaces/IREMVesting.sol";

/**
 * @title REMPresale
 * @dev A contract for managing token presales with various features including whitelisting and vesting.
 */
contract REMPresale is ReentrancyGuard, AccessControl, Pausable, IREMPresale {
    using SafeERC20 for IERC20;

    uint16 public presaleId;
    address public saleToken;
    address public vestingContract;
    address public constant NATIVE_TOKEN_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    mapping(uint256 => bool) public pausedPresales;
    mapping(uint16 => Presale) public presales;
    mapping(uint256 => mapping(address => bool)) public whitelist;

    struct UserPurchase {
        uint256 amount;
        uint256 timestamp;
    }
    // Mapping to track users and their purchases for each presale

    mapping(uint16 => address[]) public presaleUsers;
    mapping(uint16 => mapping(address => UserPurchase)) public userPurchases;

    // Mapping to track if a user has participated in a specific presale
    mapping(uint16 => mapping(address => bool)) public hasParticipated;

    modifier checkPresaleId(uint16 id) {
        if (id == 0 || id > presaleId) revert Errors.InvalidPresaleId();
        _;
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    modifier checkSaleState(uint16 id, uint256 amount) {
        if (block.timestamp < presales[id].timing.startTime || block.timestamp > presales[id].timing.endTime) {
            revert Errors.InvalidTimeForBuying();
        }
        if (amount == 0 || amount > presales[id].tokens.inSale) {
            revert Errors.InvalidSaleAmount();
        }
        if (presales[id].config.whitelistingEnabled && !whitelist[id][msg.sender]) revert Errors.NotWhitelisted();
        _;
    }

    constructor(address saleToken_, address admin, address vestingContract_) {
        if (saleToken_ == address(0)) revert Errors.ZeroTokenAddress();
        saleToken = saleToken_;
        vestingContract = vestingContract_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function createPresale(
        Timing memory presaleTimes,
        uint256 price_,
        uint256 tokensToSell_,
        address paymentToken_,
        uint256 saleTokenBaseDecimals_, // Sale token
        address destinationWallet_,
        bool whitelistingEnabled_,
        bool vestingCall_,
        VestingDetails memory vestingParams
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (presaleTimes.startTime <= block.timestamp || presaleTimes.endTime <= block.timestamp) {
            revert Errors.InvalidTime();
        }

        if (presaleTimes.endTime <= presaleTimes.startTime) {
            revert Errors.InvalidTime();
        }

        if (price_ == 0) revert Errors.ZeroPrice();
        if (tokensToSell_ == 0) revert Errors.ZeroTokensToSell();
        if (saleTokenBaseDecimals_ == 0) revert Errors.ZeroDecimalsForToken();
        if (destinationWallet_ == address(0)) {
            revert Errors.ZeroDestinationWallet();
        }
        // Check if vesting call true and TGE is unlocked in target contract
        if (vestingCall_ && IREMVesting(vestingContract).tgeUnlocked()) {
            revert Errors.TGEAlreadyUnlocked();
        }

        presaleId++;

        presales[presaleId] = Presale(
            saleToken,
            Tokens({tokensToSell: tokensToSell_, inSale: tokensToSell_}),
            Timing({startTime: presaleTimes.startTime, endTime: presaleTimes.endTime}),
            price_,
            paymentToken_,
            saleTokenBaseDecimals_,
            destinationWallet_,
            Config({whitelistingEnabled: whitelistingEnabled_, vestingCall: vestingCall_}),
            VestingDetails({
                cliffDuration: vestingParams.cliffDuration,
                vestingDuration: vestingParams.vestingDuration,
                tgePercentage: vestingParams.tgePercentage,
                groupName: vestingParams.groupName
            })
        );

        emit PresaleCreated(
            presaleId, tokensToSell_, presaleTimes, paymentToken_, whitelistingEnabled_, vestingCall_, vestingParams
        );
    }

    /**
     * @dev Cancels an existing presale
     * @param id ID of the presale to cancel
     */
    function cancelPresale(uint16 id) external checkPresaleId(id) onlyRole(DEFAULT_ADMIN_ROLE) {
        if (block.timestamp >= presales[id].timing.startTime) {
            revert Errors.SaleAlreadyStarted();
        }

        delete presales[id];
        emit PresaleCancelled(id, block.timestamp);
    }

    /**
     * @dev Changes the start and end times of a presale
     * @param id ID of the presale
     * @param startTime New start time (0 if unchanged)
     * @param endTime New end time (0 if unchanged)
     */
    function changeSaleTimes(uint16 id, uint256 startTime, uint256 endTime)
        external
        checkPresaleId(id)
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (startTime == 0 && endTime == 0) revert Errors.InvalidTime();
        if (startTime > 0) {
            if (block.timestamp >= presales[id].timing.startTime) {
                revert Errors.SaleAlreadyStarted();
            }
            if (block.timestamp >= startTime) revert Errors.SaleTimeInPast();
            uint256 prevValue = presales[id].timing.startTime;
            presales[id].timing.startTime = startTime;
            emit PresaleTimesUpdated(id, prevValue, startTime, block.timestamp, "START");
        }

        if (endTime > 0) {
            if (block.timestamp >= presales[id].timing.endTime) {
                revert Errors.SaleAlreadyEnded();
            }
            if (endTime <= presales[id].timing.startTime) {
                revert Errors.InvalidEndTime();
            }
            uint256 prevValue = presales[id].timing.endTime;
            presales[id].timing.endTime = endTime;
            emit PresaleTimesUpdated(id, prevValue, endTime, block.timestamp, "END");
        }
    }

    /**
     * @dev Changes the sale token address for a presale
     * @param id ID of the presale
     * @param newAddress New address of the sale token
     */
    function changeSaleTokenAddress(uint16 id, address newAddress)
        external
        checkPresaleId(id)
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (newAddress == address(0)) revert Errors.ZeroTokenAddress();
        if (block.timestamp >= presales[id].timing.startTime) {
            revert Errors.SaleAlreadyStarted();
        }

        address prevValue = presales[id].saleToken;
        presales[id].saleToken = newAddress;

        emit PresaleTokenAddressUpdated(id, prevValue, newAddress, block.timestamp);
    }

    /**
     * @dev Changes the price of tokens in a presale
     * @param id ID of the presale
     * @param newPrice New price of the tokens
     */
    function changePrice(uint16 id, uint256 newPrice) external checkPresaleId(id) onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newPrice == 0) revert Errors.ZeroPrice();
        if (block.timestamp >= presales[id].timing.startTime && block.timestamp <= presales[id].timing.endTime) {
            revert Errors.SaleAlreadyStarted();
        }

        uint256 prevValue = presales[id].price;
        presales[id].price = newPrice;
        emit PresalePriceUpdated(id, prevValue, newPrice, block.timestamp);
    }

    /**
     * @dev Changes the payment token for a presale
     * @param id ID of the presale
     * @param newPaymentToken New address of the payment token
     */
    function changePaymentToken(uint16 id, address newPaymentToken)
        external
        checkPresaleId(id)
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        address prevValue = presales[id].paymentToken;
        presales[id].paymentToken = newPaymentToken;
        emit PresalePaymentTokenUpdated(id, prevValue, newPaymentToken, block.timestamp);
    }

    /**
     * @dev Updates the whitelisting status for a presale
     * @param id ID of the presale
     * @param status New whitelisting status
     */
    function updateWhitelistingStatus(uint16 id, bool status)
        external
        checkPresaleId(id)
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        presales[id].config.whitelistingEnabled = status;
        emit PresaleWhitelistingStatusUpdated(id, presales[id].config.whitelistingEnabled, status, block.timestamp);
    }

    /**
     * @dev Batch updates the whitelist status for multiple users
     * @param id ID of the presale
     * @param users Array of user addresses
     * @param status Whitelist status to set for all users
     */
    function batchUpdateWhitelist(uint16 id, address[] calldata users, bool status)
        external
        checkPresaleId(id)
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        for (uint256 i; i < users.length; i++) {
            whitelist[id][users[i]] = status;
            emit WhitelistUpdated(id, users[i], status);
        }
    }

    /**
     * @dev Adds a single user to the whitelist
     * @param id ID of the presale
     * @param user Address of the user to whitelist
     */
    function addWhitelist(uint16 id, address user) external checkPresaleId(id) onlyRole(DEFAULT_ADMIN_ROLE) {
        whitelist[id][user] = true;
        emit WhitelistUserAdded(id, user, block.timestamp);
    }

    /**
     * @dev Removes a single user from the whitelist
     * @param id ID of the presale
     * @param user Address of the user to remove from whitelist
     */
    function removeWhitelist(uint16 id, address user) external checkPresaleId(id) onlyRole(DEFAULT_ADMIN_ROLE) {
        whitelist[id][user] = false;
        emit WhitelistUserRemoved(id, user, block.timestamp);
    }

    /**
     * @dev Toggles the pause state of a presale
     * @param id ID of the presale
     * @param status New pause status
     */
    function togglePausePresale(uint16 id, bool status) external checkPresaleId(id) onlyRole(DEFAULT_ADMIN_ROLE) {
        if (pausedPresales[id] == status) revert Errors.PresaleAlreadyInState();
        pausedPresales[id] = status;
        if (status) {
            emit PresalePaused(id, block.timestamp);
        } else {
            emit PresaleUnpaused(id, block.timestamp);
        }
    }

    /**
     * @dev Allows users to buy tokens in the presale
     * @param id ID of the presale
     * @param amount Amount of tokens to buy
     * @return bool Returns true if the purchase was successful
     */
    function buy(uint16 id, uint256 amount)
        external
        payable
        checkPresaleId(id)
        checkSaleState(id, amount)
        nonReentrant
        whenNotPaused
        returns (bool)
    {
        if (pausedPresales[id]) revert Errors.PresalePaused();
        uint256 wholeTokens = amount / (10 ** presales[id].baseDecimals);
        uint256 totalCost = wholeTokens * presales[id].price;
        presales[id].tokens.inSale -= amount;
        Presale memory presale = presales[id];

        // Handle payment
        if (presale.paymentToken == NATIVE_TOKEN_ADDRESS) {
            if (msg.value < totalCost) revert Errors.InsufficientPayment();
            uint256 excess = msg.value - totalCost;
            _sendValue(payable(presale.destinationWallet), totalCost);
            if (excess > 0) _sendValue(payable(msg.sender), excess);
        } else {
            IERC20 paymentToken = IERC20(presale.paymentToken);
            if (paymentToken.allowance(msg.sender, address(this)) < totalCost) {
                revert Errors.InsufficientAllowance();
            }
            paymentToken.safeTransferFrom(msg.sender, presale.destinationWallet, totalCost);
        }

        // Update user purchase information
        if (!hasParticipated[id][msg.sender]) {
            presaleUsers[id].push(msg.sender);
            hasParticipated[id][msg.sender] = true;
        }
        userPurchases[id][msg.sender].amount += amount;
        userPurchases[id][msg.sender].timestamp = block.timestamp;

        // Handle vesting if enabled
        if (presale.config.vestingCall) {
            IREMVesting vestingContractInstance = IREMVesting(vestingContract);

            // Check if TGE is unlocked
            if (vestingContractInstance.tgeUnlocked()) {
                revert Errors.TGEAlreadyUnlocked();
            }

            // Check if the beneficiary already has a vesting schedule
            IREMVesting.UserVestingInfo memory vestingInfo =
                vestingContractInstance.getVestingInfoByBeneficiary(msg.sender);

            if (vestingInfo.totalAmount > 0) {
                // Beneficiary exists, update their vesting amount
                vestingContractInstance.updateVestingAmount(msg.sender, vestingInfo.vestingAmount + amount);
            } else {
                // Create a new vesting schedule for the beneficiary
                vestingContractInstance.createVestingSchedule(
                    msg.sender,
                    amount,
                    presale.vesting.cliffDuration,
                    presale.vesting.vestingDuration,
                    presale.vesting.tgePercentage,
                    presale.vesting.groupName
                );
            }
        }

        emit TokensBought(msg.sender, id, presale.paymentToken, amount, totalCost, block.timestamp);
        return true;
    }

    /**
     * @dev Returns the purchase details of a user for a specific presale
     * @param id ID of the presale
     * @param user Address of the user
     * @return amount The amount of tokens purchased
     * @return timestamp The timestamp of the last purchase
     */
    function getUserPurchase(uint16 id, address user) external view returns (uint256 amount, uint256 timestamp) {
        UserPurchase memory purchase = userPurchases[id][user];
        return (purchase.amount, purchase.timestamp);
    }

    /**
     * @dev Returns the total amount of tokens purchased by a user across all presales
     * @param user Address of the user
     * @return totalAmount The total amount of tokens purchased
     */
    function getUserTotalPurchase(address user) external view returns (uint256 totalAmount) {
        for (uint16 i = 1; i <= presaleId; i++) {
            totalAmount += userPurchases[i][user].amount;
        }
        return totalAmount;
    }

    /**
     * @dev Retrieves a batch of users who participated in a specific presale
     * @param id ID of the presale
     * @param startIndex The starting index in the users array
     * @param endIndex The ending index in the users array (exclusive)
     * @return A array of user addresses
     */
    function getPresaleUsers(uint16 id, uint256 startIndex, uint256 endIndex)
        external
        view
        returns (address[] memory)
    {
        require(startIndex < endIndex, "Invalid index range");
        require(endIndex <= presaleUsers[id].length, "End index out of bounds");

        uint256 length = endIndex - startIndex;
        address[] memory users = new address[](length);

        for (uint256 i = 0; i < length; i++) {
            users[i] = presaleUsers[id][startIndex + i];
        }

        return users;
    }

    /**
     * @dev Returns the number of users who participated in a specific presale
     * @param id ID of the presale
     * @return The number of users
     */
    function getPresaleUserCount(uint16 id) public view returns (uint256) {
        return presaleUsers[id].length;
    }

    /**
     * @dev Internal function to send ETH
     * @param recipient Address to receive ETH
     * @param amount Amount of ETH to send
     */
    function _sendValue(address payable recipient, uint256 amount) internal {
        if (address(this).balance < amount) revert Errors.LowBalance();
        (bool success,) = recipient.call{value: amount}("");
        if (!success) revert Errors.ETHPaymentFailed();
    }
}
