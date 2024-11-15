// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IREMPresale {
    struct Tokens {
        uint256 tokensToSell;
        uint256 inSale;
    }

    struct Timing {
        uint256 startTime;
        uint256 endTime;
    }

    struct Config {
        bool whitelistingEnabled;
        bool vestingCall;
    }

    struct VestingDetails {
        uint256 cliffDuration;
        uint256 vestingDuration;
        uint256 tgePercentage;
        string groupName;
    }

    struct Presale {
        address saleToken;
        Tokens tokens;
        Timing timing;
        uint256 price;
        address paymentToken;
        uint256 baseDecimals;
        address destinationWallet;
        Config config;
        VestingDetails vesting;
    }

    event PresaleCreated(
        uint256 indexed id,
        uint256 totalTokens,
        Timing times,
        address paymentToken,
        bool whitelistingEnabled,
        bool vestingCall,
        VestingDetails vesting
    );

    event PresaleCancelled(uint256 indexed id, uint256 timestamp);

    event PresaleTimesUpdated(
        uint256 indexed id, uint256 prevValue, uint256 newValue, uint256 timestamp, string timeType
    );

    event PresaleTokenAddressUpdated(
        uint256 indexed id, address indexed prevValue, address indexed newValue, uint256 timestamp
    );

    event PresalePriceUpdated(uint256 indexed id, uint256 prevValue, uint256 newValue, uint256 timestamp);

    event PresalePaymentTokenUpdated(
        uint256 indexed id, address indexed prevValue, address indexed newPaymentToken, uint256 timestamp
    );

    event PresaleWhitelistingStatusUpdated(uint256 indexed id, bool prevValue, bool newValue, uint256 timestamp);

    event WhitelistUpdated(uint256 indexed id, address indexed user, bool whitelisted);

    event WhitelistUserAdded(uint256 indexed id, address indexed user, uint256 timestamp);

    event WhitelistUserRemoved(uint256 indexed id, address indexed user, uint256 timestamp);

    event TokensBought(
        address indexed user,
        uint256 indexed id,
        address indexed purchaseToken,
        uint256 tokensBought,
        uint256 amountPaid,
        uint256 timestamp
    );

    event PresalePaused(uint256 indexed id, uint256 timestamp);
    event PresaleUnpaused(uint256 indexed id, uint256 timestamp);
}
