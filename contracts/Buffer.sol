// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Buffer is Initializable, ReentrancyGuard {
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
    uint256 private royaltyFee = 10;

    mapping(uint256 => address) public partnersGroup;
    uint256 private partnersGroupLength = 0;
    mapping(uint256 => address) public creatorsGroup;
    uint256 private creatorsGroupLength = 0;
    mapping(uint256 => uint256) public share;
    uint256 private shareLength = 0;
    mapping(uint256 => uint256) public partnerShare;

    address public marketWallet; // wallet address for market fee

    event updateCreatorPairsInfo();

    function initialize(
        address _curator, // address for curator
        address[] calldata _partnersGroup, // array of address for partners group
        address[] memory _creatorsGroup, // array of address for creators group
        uint256[] calldata _shares, // array of share percentage for every group
        uint256[] calldata _partnerShare, // array of share percentage for every members of partners group
        address _marketWallet
    ) public initializer {
        curator = _curator;
        require(
            _partnersGroup.length > 0,
            "Please input partners group information correctly."
        );
        for (uint256 i = 0; i < _partnersGroup.length; i++) {
            for (uint256 j = 0; j < i; j++) {
                require(
                    partnersGroup[j] != _partnersGroup[i],
                    "Partner address is repeated, please check again."
                );
            }
            partnersGroup[i] = _partnersGroup[i];
            partnersGroupLength++;
        }
        require(
            _creatorsGroup.length > 0,
            "Please input creators group information correctly."
        );
        for (uint256 i = 0; i < _creatorsGroup.length; i++) {
            for (uint256 j = 0; j < i; j++) {
                require(
                    creatorsGroup[j] != _creatorsGroup[i],
                    "Creator address is repeated, please check again."
                );
            }
            creatorsGroup[i] = _creatorsGroup[i];
            creatorsGroupLength++;
        }
        require(_shares.length == 7, "Please input shares info correctly.");
        for (uint256 i = 0; i < _shares.length; i++) {
            require(
                _shares[i] > 0,
                "Total share value must be greater than 0."
            );
            totalShares += _shares[i];
            share[i] = _shares[i];
            shareLength++;
        }
        require(
            _partnersGroup.length == _partnerShare.length,
            "Please input partner group shares information correctly."
        );
        for (uint256 i = 0; i < _partnerShare.length; i++) {
            require(
                _partnerShare[i] > 0,
                "Partners' share value must be greater than 0."
            );
            totalShareOfPartners += _partnerShare[i];
            partnerShare[i] = _partnerShare[i];
        }
        marketWallet = _marketWallet;
    }

    // update creator pair info of creators addresses and tokenIDs of same lengths
    function updateCreatorPairInfo(
        address[] calldata creators,
        uint256[] calldata tokenIDs
    ) external {
        require(
            creators.length == tokenIDs.length,
            "Please input the creators info and tokenIDs as same length."
        );
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

    function shareReceived() external payable {
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

    function updateFeePercent(uint256 _royaltyFee) public {
        require(
            _royaltyFee < 20,
            "Your royalty percentage is set as over 20%."
        );
        royaltyFee = _royaltyFee;
    }

    // Withdraw
    function withdraw(
        address account, // address to ask withdraw
        address[] calldata sellerAddresses, // array of sellers address
        uint256[] calldata tokenIDs, // array of tokenIDs to be sold
        uint256[] calldata prices, // array of prices of NFTs to be sold
        // uint256 blocknumber, // current block number of transaction
        address[] calldata owners // array of current NFT owners
    ) external {
        _shareData[account].lastBlockNumber = block.number;
        uint256 leng = tokenIDs.length;
        for (uint256 i = 0; i < leng; i++) {
            _shareData[_creatorPairInfo[tokenIDs[i]]].shareAmount +=
                (share[3] * prices[i] * royaltyFee) /
                100 /
                totalShares;
            _shareData[sellerAddresses[i]].shareAmount +=
                (share[4] * prices[i] * royaltyFee) /
                100 /
                totalShares;
        }
        // OwnersGroup Calculation
        uint256 ownerLength = owners.length;
        for (uint256 i = 0; i < ownerLength; i++) {
            _shareData[owners[i]].shareAmount += totalOwnersFee / ownerLength;
        }
        totalOwnersFee = 0;
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
