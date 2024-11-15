// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IREMVesting {
    /**
     * @dev Struct to store vesting information for each user
     */
    struct UserVestingInfo {
        uint256 vestingAmount; // Amount of tokens to be vested (excluding TGE amount)
        uint256 totalAmount; // Total amount of tokens allocated (including TGE amount)
        uint256 cliffDuration; // Duration of the cliff period from contract start
        uint256 vestingDuration; // Total duration of the vesting period from contract start
        uint256 vestingReleased; // Amount of tokens released from vesting (excluding TGE)
        uint256 overallClaimed; // Total amount of tokens claimed (including TGE)
        bool tgeClaimed; // Flag indicating if TGE tokens have been claimed
        string group; // Identifier for the vesting group
        uint256 tgePercentage; // Percentage of tokens to be released at TGE
    }

    /**
     * @dev Pauses the contract
     */
    function pause() external;

    /**
     * @dev Unpauses the contract
     */
    function unpause() external;

    /**
     * @dev Creates a vesting schedule for a beneficiary
     * @param beneficiary Address of the beneficiary
     * @param totalAmount Total amount of tokens to be vested
     * @param cliffEnds Timestamp when the cliff period ends
     * @param vestingEnd Timestamp when the vesting period ends
     * @param group Identifier for the vesting group
     */
    function createVestingSchedule(
        address beneficiary,
        uint256 totalAmount,
        uint256 cliffEnds,
        uint256 vestingEnd,
        uint256 tgePercentage,
        string memory group
    ) external;

    /**
     * @dev Creates multiple vesting schedules in a batch
     * @param beneficiaries Array of beneficiary addresses
     * @param totalAmounts Array of total token amounts to be vested
     * @param cliffEnds Timestamp when the cliff period ends (same for all)
     * @param vestingEnds Timestamp when the vesting period ends (same for all)
     * @param group Identifier for the vesting group (same for all)
     */
    function batchCreateVestingSchedules(
        address[] calldata beneficiaries,
        uint256[] calldata totalAmounts,
        uint256 cliffEnds,
        uint256 vestingEnds,
        uint256 tgePercentage,
        string calldata group
    ) external;

    /**
     * @dev Deletes a beneficiary's vesting schedule
     * @param beneficiary Address of the beneficiary to be deleted
     */
    function deleteBeneficiary(address beneficiary) external;

    /**
     * @dev Updates the vesting dates for a beneficiary
     * @param beneficiary Address of the beneficiary
     * @param newCliffEnds New timestamp for when the cliff period ends
     * @param newVestingEnd New timestamp for when the vesting period ends
     */
    function updateVestingDates(address beneficiary, uint256 newCliffEnds, uint256 newVestingEnd) external;

    /**
     * @dev Updates the vesting group for a beneficiary
     * @param beneficiary Address of the beneficiary
     * @param newGroup New identifier for the vesting group
     */
    function updateVestingGroup(address beneficiary, string memory newGroup) external;

    /**
     * @dev Updates the vesting amount for a beneficiary
     * @param beneficiary Address of the beneficiary
     * @param newVestingAmount New amount of tokens to be vested
     */
    function updateVestingAmount(address beneficiary, uint256 newVestingAmount) external;

    /**
     * @dev Returns the token balance of the contract
     * @return The balance of tokens held by the contract
     */
    function balanceOf() external view returns (uint256);

    /**
     * @dev Starts the vesting contract, unlocking the TGE
     */
    function startContract() external;

    /**
     * @dev Allows beneficiaries to claim their TGE tokens
     */
    function claimTGE() external;

    /**
     * @dev Releases vested tokens to the beneficiary
     * @param amount Amount of tokens to release
     */
    function release(uint256 amount) external;

    /**
     * @dev Calculates the amount of tokens that can be released for a beneficiary
     * @param beneficiary Address of the beneficiary
     * @return The amount of tokens that can be released
     */
    function releasable(address beneficiary) external view returns (uint256);

    /**
     * @dev Emergency function to withdraw any ERC20 tokens from the contract
     * @param to Address to receive the withdrawn tokens
     * @param token_ Address of the ERC20 token to withdraw
     */
    function emergencyWithdraw(address to, address token_) external;

    /**
     * @dev Returns whether the TGE has been unlocked
     * @return Boolean indicating if TGE is unlocked
     */
    function tgeUnlocked() external view returns (bool);

    /**
     * @dev Retrieves the vesting information for a beneficiary
     * @param beneficiary Address of the beneficiary
     * @return UserVestingInfo struct containing the beneficiary's vesting details
     */
    function getVestingInfoByBeneficiary(address beneficiary) external view returns (UserVestingInfo memory);

    /**
     * @dev Event emitted when tokens are released to a beneficiary
     * @param beneficiary Address of the beneficiary
     * @param amount Amount of tokens released
     */
    event Released(address indexed beneficiary, uint256 amount);

    /**
     * @dev Event emitted when a new vesting schedule is created
     * @param beneficiary Address of the beneficiary
     * @param totalAmount Total amount of tokens to be vested
     * @param vestingAmount Amount of tokens to be vested (excluding TGE amount)
     * @param tgeAmount Amount of tokens to be released at TGE
     * @param cliffDuration Duration of the cliff period
     * @param vestingDuration Total duration of the vesting period
     * @param group Group identifier for the vesting schedule
     */
    event VestingScheduleCreated(
        address indexed beneficiary,
        uint256 totalAmount,
        uint256 vestingAmount,
        uint256 tgeAmount,
        uint256 cliffDuration,
        uint256 vestingDuration,
        uint256 tgePercentage,
        string group
    );

    /**
     * @dev Event emitted when vesting amount is increased for a beneficiary
     * @param beneficiary Address of the beneficiary
     * @param additionalAmount Amount of tokens added to the vesting schedule
     * @param newTotalAmount New total amount of tokens in the vesting schedule
     * @param newVestingAmount New amount of tokens to be vested (excluding TGE amount)
     * @param newTgeAmount New amount of tokens to be released at TGE
     */
    event VestingAmountIncreased(
        address indexed beneficiary,
        uint256 additionalAmount,
        uint256 newTotalAmount,
        uint256 newVestingAmount,
        uint256 newTgeAmount
    );

    /**
     * @dev Event emitted when a beneficiary's vesting schedule is deleted
     * @param beneficiary Address of the deleted beneficiary
     * @param unreleasedAmount Amount of unreleased tokens returned
     */
    event BeneficiaryDeleted(address indexed beneficiary, uint256 unreleasedAmount);

    /**
     * @dev Event emitted when a beneficiary's vesting amount is updated
     * @param beneficiary Address of the beneficiary
     * @param newVestingAmount New amount of tokens to be vested
     * @param newTotalAmount New total amount of tokens allocated
     */
    event VestingAmountUpdated(address indexed beneficiary, uint256 newVestingAmount, uint256 newTotalAmount);

    /**
     * @dev Event emitted when a beneficiary's vesting dates are updated
     * @param beneficiary Address of the beneficiary
     * @param newCliffEnds New timestamp for when the cliff period ends
     * @param newVestingEnd New timestamp for when the vesting period ends
     */
    event VestingDatesUpdated(address indexed beneficiary, uint256 newCliffEnds, uint256 newVestingEnd);

    /**
     * @dev Event emitted when a beneficiary's vesting group is updated
     * @param beneficiary Address of the beneficiary
     * @param newGroup New identifier for the vesting group
     */
    event VestingGroupUpdated(address indexed beneficiary, string newGroup);
}
