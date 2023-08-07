// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {EarthAutoCompoundingVault} from "@earth/vaults/EarthAutoCompoundingVault.sol";

contract EarthAutoCompoundingVaultPublic is EarthAutoCompoundingVault {
    constructor(
        address asset_,
        string memory _name,
        string memory _symbol,
        uint256 _approvalDelay,
        uint256 _totalTvlCap
    )
        EarthAutoCompoundingVault(
            asset_,
            _name,
            _symbol,
            _approvalDelay,
            _totalTvlCap
        )
    {}

    ///@dev hook function for access control of the vault. Has to be overriden in inheriting contracts to only give access for relevant parties.
    function _restrictAccess() internal view override {}
}
