// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Errors} from "./libs/Errors.sol";
import {IREMVesting} from "./interfaces/IREMVesting.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title REMVesting
 * @dev A contract for managing token vesting schedules with TGE (Token Generation Event) functionality.
 * This contract allows for creating, managing, and executing vesting schedules for token distribution.
 */
contract REMVesting is AccessControl, Pausable, IREMVesting, ReentrancyGuard {
    using SafeERC20 for ERC20;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    uint16 public constant DENOMINATOR = 10_000;

    uint256 public overallTotalAmount;
    uint256 public overallClaimedAmount;
    uint256 public contractStartTime;
    ERC20 public token;
    bool public tgeUnlocked;
    address public recoveryAddress;

    // Mapping to store vesting information for each beneficiary
    mapping(address user => UserVestingInfo) public vestingInfoByBeneficiary;

    constructor(address admin, address manager, address recoveryAddress_, address tokenAddress) {
        if (admin == address(0) || manager == address(0) || tokenAddress == address(0)) {
            revert Errors.AddressZeroProvided();
        }
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MANAGER_ROLE, admin);
        _grantRole(MANAGER_ROLE, manager);
        token = ERC20(tokenAddress);
        recoveryAddress = recoveryAddress_;
    }

    /**
     * @dev Function to pause the contract
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Function to unpause the contract
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @dev Function to create vesting schedules in batch
     * @param beneficiaries Array of beneficiary addresses
     * @param totalAmounts Array of total token amounts to be vested
     * @param cliffDuration Timestamp when the cliff period ends
     * @param vestingDuration Timestamp when the vesting period ends
     * @param group Group identifier for the vesting schedule
     */
    function batchCreateVestingSchedules(
        address[] calldata beneficiaries,
        uint256[] calldata totalAmounts,
        uint256 cliffDuration,
        uint256 vestingDuration,
        uint256 tgePercentage,
        string calldata group
    ) external onlyRole(MANAGER_ROLE) {
        if (tgePercentage > DENOMINATOR) revert Errors.InvalidPercentage();
        if (beneficiaries.length != totalAmounts.length) revert Errors.InvalidBatchInput();

        for (uint256 i = 0; i < beneficiaries.length; i++) {
            createVestingSchedule(
                beneficiaries[i], totalAmounts[i], cliffDuration, vestingDuration, tgePercentage, group
            );
        }
    }

    /**
     * @dev Creates a new vesting schedule for a beneficiary
     * @param beneficiary Address of the beneficiary
     * @param totalAmount Total amount of tokens to be vested
     * @param cliffDuration Timestamp when the cliff period ends
     * @param vestingDuration Timestamp when the vesting period ends
     * @param group Group identifier for the vesting schedule
     */
    function createVestingSchedule(
        address beneficiary,
        uint256 totalAmount,
        uint256 cliffDuration,
        uint256 vestingDuration,
        uint256 tgePercentage,
        string memory group
    ) public onlyRole(MANAGER_ROLE) {
        if (beneficiary == address(0)) revert Errors.AddressZeroProvided();
        if (vestingInfoByBeneficiary[beneficiary].totalAmount != 0) revert Errors.ScheduleAlreadyExists();
        uint256 tgeAmount = (totalAmount * tgePercentage) / DENOMINATOR;
        uint256 vestingAmount = totalAmount - tgeAmount;

        vestingInfoByBeneficiary[beneficiary] = UserVestingInfo({
            vestingAmount: vestingAmount,
            totalAmount: totalAmount,
            cliffDuration: cliffDuration,
            vestingDuration: vestingDuration,
            vestingReleased: 0,
            overallClaimed: 0,
            tgeClaimed: false,
            group: group,
            tgePercentage: tgePercentage
        });
        overallTotalAmount += totalAmount;

        if (tgeUnlocked) {
            token.safeTransferFrom(msg.sender, address(this), totalAmount);
        }
        // Emit the event
        emit VestingScheduleCreated(
            beneficiary, totalAmount, vestingAmount, tgeAmount, cliffDuration, vestingDuration, tgePercentage, group
        );
    }

    /**
     * @dev Function to delete a beneficiary's vesting schedule
     * @param beneficiary Address of the beneficiary
     */
    function deleteBeneficiary(address beneficiary) external onlyRole(MANAGER_ROLE) {
        UserVestingInfo storage vestingInfo = vestingInfoByBeneficiary[beneficiary];
        if (vestingInfo.totalAmount == 0) revert Errors.NoExistingSchedule();
        if (
            contractStartTime > 0
                && block.timestamp >= contractStartTime + vestingInfo.cliffDuration + vestingInfo.vestingDuration
        ) revert Errors.VestingAlreadyEnded();
        if (contractStartTime > 0 && block.timestamp >= contractStartTime + vestingInfo.cliffDuration) {
            revert Errors.VestingStartedAlready();
        }

        uint256 unreleasedAmount = vestingInfo.vestingAmount - vestingInfo.vestingReleased;
        overallTotalAmount -= unreleasedAmount;

        delete vestingInfoByBeneficiary[beneficiary];
        if (tgeUnlocked) {
            token.safeTransfer(recoveryAddress, unreleasedAmount);
        }

        emit BeneficiaryDeleted(beneficiary, unreleasedAmount);
    }

    /**
     * @dev Function to update vesting dates for a beneficiary
     * @param beneficiary Address of the beneficiary
     * @param newCliffDuration New timestamp when the cliff period ends
     * @param newVestingDuration New timestamp when the vesting period ends
     */
    function updateVestingDates(address beneficiary, uint256 newCliffDuration, uint256 newVestingDuration)
        external
        onlyRole(MANAGER_ROLE)
    {
        if (tgeUnlocked) revert Errors.VestingAlreadyStarted();
        UserVestingInfo storage vestingInfo = vestingInfoByBeneficiary[beneficiary];
        if (vestingInfo.totalAmount == 0) revert Errors.NoExistingSchedule();
        if (newVestingDuration <= newCliffDuration) revert Errors.InvalidVestingPeriod();

        vestingInfo.cliffDuration = newCliffDuration;
        vestingInfo.vestingDuration = newVestingDuration;

        emit VestingDatesUpdated(beneficiary, newCliffDuration, newVestingDuration);
    }

    /**
     * @dev Function to update the vesting group for a beneficiary
     * @param beneficiary Address of the beneficiary
     * @param newGroup New group identifier for the vesting schedule
     */
    function updateVestingGroup(address beneficiary, string memory newGroup) external onlyRole(MANAGER_ROLE) {
        if (tgeUnlocked) revert Errors.VestingAlreadyStarted();
        UserVestingInfo storage vestingInfo = vestingInfoByBeneficiary[beneficiary];
        if (vestingInfo.totalAmount == 0) revert Errors.NoExistingSchedule();

        vestingInfo.group = newGroup;

        emit VestingGroupUpdated(beneficiary, newGroup);
    }

    /**
     * @dev Function to update the vesting amount for a beneficiary
     * @param beneficiary Address of the beneficiary
     * @param newVestingAmount New vesting amount for the beneficiary
     */
    function updateVestingAmount(address beneficiary, uint256 newVestingAmount) external onlyRole(MANAGER_ROLE) {
        if (tgeUnlocked) revert Errors.VestingAlreadyStarted();
        UserVestingInfo storage vestingInfo = vestingInfoByBeneficiary[beneficiary];
        if (vestingInfo.totalAmount == 0) revert Errors.NoExistingSchedule();

        uint256 oldTotalAmount = vestingInfo.totalAmount;
        uint256 newTgeAmount = (newVestingAmount * vestingInfo.tgePercentage) / DENOMINATOR;
        uint256 newTotalAmount = newVestingAmount - newTgeAmount;

        overallTotalAmount = overallTotalAmount - oldTotalAmount + newTotalAmount;

        vestingInfo.vestingAmount = newVestingAmount;
        vestingInfo.totalAmount = newTotalAmount;

        emit VestingAmountUpdated(beneficiary, newVestingAmount, newTotalAmount);
    }

    /**
     * @dev Adds more tokens to an existing vesting schedule
     * @param beneficiary Address of the beneficiary
     * @param additionalAmount Amount of tokens to add to the vesting schedule
     */
    function addVestingAmount(address beneficiary, uint256 additionalAmount) external onlyRole(MANAGER_ROLE) {
        if (tgeUnlocked) revert Errors.VestingAlreadyStarted();

        UserVestingInfo storage vestingInfo = vestingInfoByBeneficiary[beneficiary];
        if (vestingInfo.totalAmount == 0) revert Errors.NoExistingSchedule();
        if (additionalAmount == 0) revert Errors.InvalidAmount();

        uint256 newTotalAmount = vestingInfo.totalAmount + additionalAmount;
        uint256 newTgeAmount = (newTotalAmount * vestingInfo.tgePercentage) / DENOMINATOR;
        uint256 newVestingAmount = newTotalAmount - newTgeAmount;

        vestingInfo.totalAmount = newTotalAmount;
        vestingInfo.vestingAmount = newVestingAmount;

        overallTotalAmount += additionalAmount;

        emit VestingAmountIncreased(beneficiary, additionalAmount, newTotalAmount, newVestingAmount, newTgeAmount);
    }

    /**
     * @dev Returns the token balance of the contract
     * @return The balance of tokens held by the contract
     */
    function balanceOf() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    /**
     * @dev Starts the vesting contract, unlocking the TGE
     * Can only be called by the DEFAULT_ADMIN_ROLE
     */
    function startContract() external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (tgeUnlocked) revert Errors.AlreadyUnlocked();
        tgeUnlocked = true;
        contractStartTime = block.timestamp;

        uint256 currentBalance = token.balanceOf(address(this));
        uint256 requiredAmount = overallTotalAmount > currentBalance ? overallTotalAmount - currentBalance : 0;

        if (requiredAmount > 0) {
            token.safeTransferFrom(msg.sender, address(this), requiredAmount);
        }
    }

    /**
     * @dev Allows beneficiaries to claim their TGE tokens
     */
    function claimTGE() external whenNotPaused nonReentrant {
        UserVestingInfo storage vestingInfo = vestingInfoByBeneficiary[msg.sender];
        if (!tgeUnlocked || vestingInfo.tgeClaimed) revert Errors.ContractNotStarted();
        uint256 tgeAmount = (vestingInfo.totalAmount * vestingInfo.tgePercentage) / DENOMINATOR;
        vestingInfo.tgeClaimed = true;
        overallClaimedAmount += tgeAmount;
        vestingInfo.overallClaimed += tgeAmount;
        token.safeTransfer(msg.sender, tgeAmount);
    }

    /**
     * @dev Allows beneficiaries to release their vested tokens
     * @param amount The amount of tokens to release
     */
    function release(uint256 amount) external whenNotPaused nonReentrant {
        if (!tgeUnlocked) revert Errors.ContractNotStarted();
        UserVestingInfo storage vestingInfo = vestingInfoByBeneficiary[msg.sender];
        uint256 releasableAmount = releasable(msg.sender);

        if (amount <= 0 || amount > releasableAmount) revert Errors.InvalidAmount();
        vestingInfo.vestingReleased += amount;
        overallClaimedAmount += amount;
        vestingInfo.overallClaimed += amount;
        token.safeTransfer(msg.sender, amount);

        emit Released(msg.sender, amount);
    }

    /**
     * @dev Calculates the amount of tokens that can be released for a beneficiary
     * @param beneficiary Address of the beneficiary
     * @return The amount of tokens that can be released
     */
    function releasable(address beneficiary) public view returns (uint256) {
        UserVestingInfo memory vestingInfo = vestingInfoByBeneficiary[beneficiary];
        if (contractStartTime == 0 || block.timestamp < contractStartTime + vestingInfo.cliffDuration) {
            return 0;
        }

        uint256 vestingDurationElapsed = block.timestamp - (contractStartTime + vestingInfo.cliffDuration);

        if (vestingDurationElapsed >= vestingInfo.vestingDuration) {
            return vestingInfo.vestingAmount - vestingInfo.vestingReleased;
        }

        uint256 unlockingPercentage = (DENOMINATOR * vestingDurationElapsed) / vestingInfo.vestingDuration;

        uint256 vestedSinceStart = (vestingInfo.vestingAmount * unlockingPercentage) / DENOMINATOR;
        return vestedSinceStart - vestingInfo.vestingReleased;
    }

    function emergencyWithdraw(address to, address token_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = ERC20(token_).balanceOf(address(this));
        ERC20(token_).safeTransfer(to, balance);
    }

    // Function to get vesting information for a beneficiary
    function getVestingInfoByBeneficiary(address beneficiary) external view returns (UserVestingInfo memory) {
        return vestingInfoByBeneficiary[beneficiary];
    }
}
