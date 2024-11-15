// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {
    uint8 private _customDecimals;

    constructor(address mintTo, uint8 decimals_) ERC20("Mock Token", "MKT") {
        _customDecimals = decimals_;
        _mint(mintTo, 1000 * (10 ** decimals_));
    }

    function decimals() public view virtual override returns (uint8) {
        return _customDecimals;
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
