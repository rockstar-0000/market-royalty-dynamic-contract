// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract Buffer is Initializable {
    uint256 public totalReceived;
    struct ShareData {
        uint256 shareAmount;
        uint256 lastBlockNumber;
        uint256 withdrawn;
    }

    mapping(address => ShareData) public _shareData;
    mapping(uint256 => address) public _creatorPairInfo;

    address public curator;
    uint256 public totalShares = 0;
    uint256 private totalOwnersFee;
    uint256 private totalShareOfPartners = 0;

    mapping(uint256 => address) public partnersGroup;
    uint256 private partnersGroupLength = 0;
    mapping(uint256 => address) public creatorsGroup;
    uint256 private creatorsGroupLength = 0;
    mapping(uint256 => uint256) public share;
    uint256 private shareLength = 0;
    mapping(uint256 => uint256) public partnerShare;

    address public marketWallet; // wallet address for market fee

    function initialize(
        address _curator, // address for curator
        address[] memory _partnersGroup, // array of address for partners group
        address[] memory _creatorsGroup, // array of address for creators group
        uint256[] memory _shares, // array of share percentage for every group
        uint256[] memory _partnerShare // array of share percentage for every members of partners group
    ) public initializer {
        for (uint256 i = 0; i < _shares.length; i++) {
            totalShares += _shares[i];
            share[i] = _shares[i];
            shareLength++;
        }
        curator = _curator;
        for (uint256 i = 0; i < _partnersGroup.length; i++) {
            partnersGroup[i] = _partnersGroup[i];
            partnersGroupLength++;
        }
        for (uint256 i = 0; i < _creatorsGroup.length; i++) {
            creatorsGroup[i] = _creatorsGroup[i];
            creatorsGroupLength++;
        }
        for (uint256 i = 0; i < _partnerShare.length; i++) {
            totalShareOfPartners += _partnerShare[i];
            partnerShare[i] = _partnerShare[i];
        }
        marketWallet = 0x13f41aa17Bf27d9d18910683b8fF61Eb8c992855;
    }

    // update creator pair info of creators addresses and tokenIDs of same lengths
    function updateCreatorPairInfo(
        address[] memory creators,
        uint256[] memory tokenIDs
    ) external {
        for (uint256 i = 0; i < creators.length; i++) {
            uint256 checkValidInfo = 0;
            for (uint256 j = 0; j < creatorsGroupLength; j++) {
                if (creators[i] == creatorsGroup[j]) {
                    checkValidInfo = 1;
                    break;
                }
            }
            require(
                checkValidInfo == 1,
                "You input invalid creators pair info, please check them carefully and input valid info!"
            );
            _creatorPairInfo[tokenIDs[i]] = creators[i];
        }
    }

    receive() external payable {
        totalReceived += msg.value;
        totalOwnersFee += (msg.value * share[5]) / totalShares;
        // Marketplace Calculation
        _shareData[marketWallet].shareAmount +=
            (msg.value * share[6]) /
            totalShares;
        // Curator Calculation
        _shareData[curator].shareAmount += (msg.value * share[0]) / totalShares;
        // partnersGroup Calculation
        for (uint256 i = 0; i < partnersGroupLength; i++) {
            _shareData[partnersGroup[i]].shareAmount +=
                (((msg.value * share[1]) / totalShares) * partnerShare[i]) /
                totalShareOfPartners;
        }
        // creatorsGroup Calculation
        for (uint256 i = 0; i < creatorsGroupLength; i++) {
            _shareData[creatorsGroup[i]].shareAmount +=
                (msg.value * share[2]) /
                creatorsGroupLength /
                totalShares;
        }
    }

    // Get the last block number
    function getBlockNumber(address account) external view returns (uint256) {
        return _shareData[account].lastBlockNumber;
    }

    // Withdraw
    function withdraw(
        address account, // address to ask withdraw
        address[] memory sellerAddresses, // array of sellers address
        uint256[] memory tokenIDs, // array of tokenIDs to be sold
        uint256[] memory prices, // array of prices of NFTs to be sold
        uint256 blocknumber, // current block number of transaction
        address[] memory owners // array of current NFT owners
    ) external payable {
        _shareData[account].lastBlockNumber = blocknumber;
        uint256 leng = tokenIDs.length;
        for (uint256 i = 0; i < leng; i++) {
            _shareData[_creatorPairInfo[tokenIDs[i]]].shareAmount +=
                (share[3] * prices[i] * 10) /
                100 /
                totalShares;
            _shareData[sellerAddresses[i]].shareAmount +=
                (share[4] * prices[i] * 10) /
                100 /
                totalShares;
        }
        // OwnersGroup Calculation
        uint256 ownerLength = owners.length;
        for (uint256 i = 0; i < ownerLength; i++) {
            _shareData[owners[i]].shareAmount += totalOwnersFee / ownerLength;
        }
        totalOwnersFee = 0;
        require(
            _shareData[account].shareAmount > 0,
            "Claim is not allowed as of now due to the 0 balance. Please check it later"
        );
        if (_shareData[account].shareAmount > 0) {
            _shareData[account].withdrawn += _shareData[account].shareAmount;
            _transfer(account, _shareData[account].shareAmount);
            _shareData[account].shareAmount = 0;
        }
    }

    // adopted from https://github.com/lexDAO/Kali/blob/main/contracts/libraries/SafeTransferLib.sol
    error TransferFailed();

    function _transfer(address to, uint256 amount) internal {
        bool callStatus;
        assembly {
            callStatus := call(gas(), to, amount, 0, 0, 0, 0)
        }
        if (!callStatus) revert TransferFailed();
    }
}
