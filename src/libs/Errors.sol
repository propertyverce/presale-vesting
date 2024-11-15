// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

library Errors {
    error AddressZeroProvided();
    error AmountTooSmall();
    error VestingUnavailable(uint256 vestingScheduleId);
    error InvalidAmount();
    error TransferFailed();
    error ContractNotStarted();
    error AlreadyUnlocked();
    error InvalidTime();
    error ZeroPrice();
    error ZeroTokensToSell();
    error ZeroDecimalsForToken();
    error SaleAlreadyStarted();
    error SaleTimeInPast();
    error SaleAlreadyEnded();
    error InvalidEndTime();
    error ZeroTokenAddress();
    error InvalidPresaleId();
    error InvalidTimeForBuying();
    error InvalidSaleAmount();
    error NotWhitelisted();
    error PresalePaused();
    error InsufficientPayment();
    error InsufficientAllowance();
    error TokenTransferFailed();
    error LowBalance();
    error ETHPaymentFailed();
    error PresaleAlreadyInState();
    error ZeroDestinationWallet();
    error InvalidVestingPeriod();
    error NoExistingSchedule();
    error VestingAlreadyEnded();
    error VestingStartedAlready();
    error InvalidBatchInput();
    error VestingAlreadyStarted();
    error TGEAlreadyUnlocked();
    error ScheduleAlreadyExists();
    error InvalidVestingDurations();
    error InvalidPercentage();
}
