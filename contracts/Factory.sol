// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import "./Buffer.sol";

contract Factory {
    event ContractDeployed(
        address indexed owner,
        address indexed group,
        string title
    );
    address public immutable implementation;

    constructor() {
        implementation = address(new Buffer());
    }

    function genesis(
        string memory title,
        address _curator,
        address[] memory _partnersGroup,
        address[] memory _creatorsGroup,
        uint256[] memory _shares,
        uint256[] memory _partnerShare
    ) external returns (address) {
        address payable clone = payable(
            ClonesUpgradeable.clone(implementation)
        );
        Buffer buffer = Buffer(clone);
        buffer.initialize(
            _curator,
            _partnersGroup,
            _creatorsGroup,
            _shares,
            _partnerShare
        );
        emit ContractDeployed(msg.sender, clone, title);
        return clone;
    }
}
