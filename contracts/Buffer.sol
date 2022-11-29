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

    address public curator;
    uint256 private totalOwnersFee;
    uint256 public royaltyFee = 10;

    mapping(address => ShareData) public _shareData;
    mapping(uint256 => address) private _creatorPairInfo;
    uint256 public totalShares;
    uint256 public totalSharesOfPartners;
    mapping(uint256 => address) private partnersGroup;
    uint256 private partnersGroupLength = 0;
    mapping(uint256 => address) private creatorsGroup;
    uint256 private creatorsGroupLength = 0;
    mapping(uint256 => address) private sellersGroup;
    uint256 private sellersGroupLength = 0;

    //////////
    mapping(uint256 => uint256) public shareDetails;
    uint256 private shareDetailLength = 0;
    mapping(uint256 => uint256) public partnerShareDetails;
    address private deadAddress = 0x0000000000000000000000000000000000000000;
    uint256 private smallestCnt = 0;
    uint256 private totalCntOfContent = 0;
    //////////

    // uint256 mintStage = 50001;
    // uint256 saleStage = 50002;

    address public marketWallet; // wallet address for market fee

    address public owner;
    modifier onlyOwner() {
        require(owner == msg.sender, "Caller is not the owner.");
        _;
    }

    event UpdateCreatorPairsCheck(bool updated);
    event UpdateCreatorsGroupCheck(bool updateGroup);
    event UpdateFeeCheck(uint256 feePercent);
    event WithdrawnCheck(address to, uint256 amount);
    event UpdateSharesCheck(uint256[] share, uint256[] partnerShare);

    function initialize(
        address _owner,
        address _curator, // address for curator
        address[] memory _partnersGroup, // array of address for partners group
        address[] memory _creatorsGroup, // array of address for creators group
        uint256[] calldata _shares, // array of share percentage for every group
        uint256[] calldata _partnerShare, // array of share percentage for every members of partners group
        address _marketWallet
    ) public payable initializer {
        curator = _curator;

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
        for (uint256 i = 0; i < _shares.length - 1; i++) {
            //////////
            totalShares += _shares[i];
            shareDetails[i] = _shares[i];
            shareDetailLength++;
            //////////
        }
        require(totalShares > 0, "Sum of share percentages must be greater than 0.");
        require(
            _partnersGroup.length == _partnerShare.length,
            "Please input partner group shares information correctly."
        );
        for (uint256 i = 0; i < _partnerShare.length; i++) {
            totalSharesOfPartners += _partnerShare[i];
            //////////
            partnerShareDetails[i] = _partnerShare[i];
            //////////
        }
        marketWallet = _marketWallet;
        owner = _owner;
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        owner = _newOwner;
    }

    // update creator pair info of creators addresses and tokenIDs of same lengths
    function updateCreatorPairInfo(
        address[] calldata creators,
        uint256[] calldata numOfTokens
    ) external onlyOwner {
        require(
            creators.length == numOfTokens.length,
            "Please input the creators info and tokenIDs as same length."
        );
        // for (uint256 i = 0; i < creators.length; i++) {
        //     uint256 checkValidInfo = 0;
        //     for (uint256 j = 0; j < creatorsGroupLength; j++) {
        //         if (creators[i] == creatorsGroup[j]) {
        //             checkValidInfo = 1;
        //             break;
        //         }
        //     }
        //     require(
        //         checkValidInfo == 1,
        //         "You input invalid creators pair info, please check them carefully and input valid info!"
        //     );
        //     _creatorPairInfo[tokenIDs[i]] = creators[i];
        // }
        uint256 i;
        uint256 tmp = 0;
        for (i = 0; i < creators.length; i++) {
            tmp += numOfTokens[i];
        }

        for (i = 0; i < numOfTokens.length; i++) {
            totalCntOfContent += numOfTokens[i];
            if (smallestCnt > totalCntOfContent) {
                smallestCnt = totalCntOfContent;
            }
            _creatorPairInfo[totalCntOfContent] = creators[i];
        }

        emit UpdateCreatorPairsCheck(true);
    }

    function updateCreatorsGroup(address[] calldata _creatorsGroup)
        external
        onlyOwner
    {
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
        emit UpdateCreatorsGroupCheck(true);
    }

    function shareReceived() external payable {
        totalReceived += msg.value;

        totalOwnersFee += (msg.value * shareDetails[5]) / totalShares;
        // Marketplace Calculation
        // _shareData[marketWallet].shareAmount +=
        //     (msg.value * shareDetails[6]) /
        //     totalShares;
        // Curator Calculation
        _shareData[curator].shareAmount += (msg.value * shareDetails[0]) / totalShares;
        // partnersGroup Calculation
        for (uint256 i = 0; i < partnersGroupLength; i++) {
            _shareData[partnersGroup[i]].shareAmount += (((msg.value * shareDetails[1]) / totalShares) * partnerShareDetails[i]) / totalSharesOfPartners;
        }
        // creatorsGroup Calculation
        for (uint256 i = 0; i < creatorsGroupLength; i++) {
            _shareData[creatorsGroup[i]].shareAmount += (msg.value * shareDetails[2]) / creatorsGroupLength / totalShares;
        }
    }

    // Get the last block number
    function getBlockNumber(address account) external view returns (uint256) {
        return _shareData[account].lastBlockNumber;
    }

    function updateFeePercent(uint256 _royaltyFee) public onlyOwner {
        require(
            _royaltyFee < 20,
            "Your royalty percentage is set as over 20%."
        );
        royaltyFee = _royaltyFee;
        emit UpdateFeeCheck(royaltyFee);
    }

    function updateRoyaltyPercentage(uint256[] calldata _share, uint256[] calldata _partnerShare) external onlyOwner {
        require(_share.length == shareDetailLength + 1, "Please input share info correctly");
        require(_partnerShare.length == partnersGroupLength, "Please input partners share info correctly");
        // require(_stage == mintStage || _stage == saleStage, "Please input correct number for stage.");

        uint256 totalTmp = 0;
        uint256 partnersTmp = 0;

        for (uint256 i =0; i < _share.length - 1; i++) {
            shareDetails[i] = _share[i];
            totalTmp += _share[i];
        }

        for (uint256 i = 0; i < _partnerShare.length; i++) {
            partnerShareDetails[i] = _partnerShare[i];
            partnersTmp += _partnerShare[i];
        }

        require(totalTmp > 0, "Please input valid share info. Sum of them must be greater than 0.");
        totalShares = totalTmp;
        totalSharesOfPartners = partnersTmp;

        emit UpdateSharesCheck(_share, _partnerShare);
    }

    // Withdraw
    function withdraw(
        address account, // address to ask withdraw
        address[] calldata sellerAddresses, // array of sellers address
        uint256[] calldata tokenIDs, // array of tokenIDs to be sold
        uint256[] calldata prices, // array of prices of NFTs to be sold
        address[] memory owners // array of current NFT owners
    ) external nonReentrant {
        _shareData[account].lastBlockNumber = block.number;
        uint256 index = 0;
        for (uint256 i = 0; i < tokenIDs.length; i++) {
            if (tokenIDs[i] < smallestCnt) {
                index = smallestCnt;
            } else {
                for (index = tokenIDs[i]; index <= totalCntOfContent; index++) {
                    if (keccak256(abi.encodePacked(_creatorPairInfo[tokenIDs[i]])) != keccak256(abi.encodePacked(""))) {
                        break;
                    }
                }
            }

            _shareData[_creatorPairInfo[index]].shareAmount += shareDetails[3] * prices[i] * royaltyFee / 100 / totalShares;
            if (sellerAddresses[i] != deadAddress) {
                _shareData[sellerAddresses[i]].shareAmount += shareDetails[4] * prices[i] * royaltyFee / 100 / totalShares;
            }
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
        emit WithdrawnCheck(account, _shareData[account].shareAmount);
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
