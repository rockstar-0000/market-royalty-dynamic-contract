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
    uint256 private totalShareOfPartnersMint = 0;
    uint256 private totalShareOfPartnersSale = 0;
    uint256 public royaltyFee = 10;

    mapping(address => ShareData) public _shareData;
    mapping(uint256 => address) private _creatorPairInfo;
    mapping(uint256 => uint256) public totalShares;
    mapping(uint256 => address) private partnersGroup;
    uint256 private partnersGroupLength = 0;
    mapping(uint256 => address) private creatorsGroup;
    uint256 private creatorsGroupLength = 0;
    // mapping(uint256 => uint256) public share;
    // uint256 private shareLength = 0;
    // mapping(uint256 => uint256) public partnerShare;

    //////////
    mapping(uint256 => mapping(uint256 => uint256)) public shareDetails;
    uint256 private shareDetailLength = 0;
    mapping(uint256 => mapping(uint256 => uint256)) public partnerShareDetails;
    address private deadAddress = 0x0000000000000000000000000000000000000000;
    //////////

    uint256 mintStage = 50001;
    uint256 saleStage = 50002;

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
    event UpdateSharesMintCheck(uint256[] shareMint, uint256[] partnerShareMint);

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
            //////////
            totalShares[saleStage] += _shares[i];
            shareDetails[saleStage][i] = _shares[i];
            shareDetailLength++;
            //////////
            // share[i] = _shares[i];
            // shareLength++;
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
            totalShareOfPartnersSale += _partnerShare[i];
            //////////
            partnerShareDetails[saleStage][i] = _partnerShare[i];
            //////////
            // partnerShare[i] = _partnerShare[i];
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
        uint256[] calldata tokenIDs
    ) external onlyOwner {
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

    function shareReceived(uint256 stage) external payable {
        totalReceived += msg.value;

        // totalOwnersFee += (msg.value * share[5]) / totalSharesSale;
        totalOwnersFee += (msg.value * shareDetails[stage][5]) / totalShares[stage];
        // Marketplace Calculation
        // _shareData[marketWallet].shareAmount +=
        //     (msg.value * share[6]) /
        //     totalSharesSale;
        _shareData[marketWallet].shareAmount +=
            (msg.value * shareDetails[stage][6]) /
            totalShares[stage];
        // Curator Calculation
        // _shareData[curator].shareAmount += (msg.value * share[0]) / totalSharesSale;
        _shareData[curator].shareAmount += (msg.value * shareDetails[stage][0]) / totalShares[stage];
        // partnersGroup Calculation
        for (uint256 i = 0; i < partnersGroupLength; i++) {
            // _shareData[partnersGroup[i]].shareAmount +=
            //     (((msg.value * share[1]) / totalSharesSale) * partnerShare[i]) /
            //     totalShareOfPartnersSale;
            _shareData[partnersGroup[i]].shareAmount +=
                (((msg.value * shareDetails[stage][1]) / totalShares[stage]) * partnerShareDetails[stage][i]) /
                totalShareOfPartnersSale;
        }
        // creatorsGroup Calculation
        for (uint256 i = 0; i < creatorsGroupLength; i++) {
            _shareData[creatorsGroup[i]].shareAmount +=
                (msg.value * shareDetails[stage][2]) /
                creatorsGroupLength /
                totalShares[stage];
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

    function updateRoyaltyPercentageMint(uint256[] calldata _shareMint, uint256[] calldata _partnerShareMint) external onlyOwner {
        require(_shareMint.length == shareDetailLength, "Please input share info for mint stage correctly");
        require(_partnerShareMint.length == partnersGroupLength, "Please input partners share info for mint stage correctly");

        for (uint256 i =0; i < _shareMint.length; i++) {
            shareDetails[mintStage][i] = _shareMint[i];
        }

        for (uint256 i = 0; i < _partnerShareMint.length; i++) {
            partnerShareDetails[mintStage][i] = _partnerShareMint[i];
        }

        emit UpdateSharesMintCheck(_shareMint, _partnerShareMint);
    }

    // Withdraw
    function withdraw(
        address account, // address to ask withdraw
        address[] calldata sellerAddresses, // array of sellers address
        uint256[] calldata tokenIDs, // array of tokenIDs to be sold
        uint256[] calldata prices, // array of prices of NFTs to be sold
        address[] memory creators,
        address[] memory owners // array of current NFT owners
    ) external nonReentrant {
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
        }
        _shareData[account].lastBlockNumber = block.number;
        uint256 leng = tokenIDs.length;
        for (uint256 i = 0; i < leng; i++) {
            if (sellerAddresses[i] != deadAddress) {
                _shareData[_creatorPairInfo[tokenIDs[i]]].shareAmount +=
                    (shareDetails[saleStage][3] * prices[i] * royaltyFee) /
                    100 /
                    totalShares[saleStage];
                _shareData[sellerAddresses[i]].shareAmount +=
                    (shareDetails[saleStage][4] * prices[i] * royaltyFee) /
                    100 /
                    totalShares[saleStage];
            } else {
                _shareData[_creatorPairInfo[tokenIDs[i]]].shareAmount +=
                    (shareDetails[mintStage][3] * prices[i] * royaltyFee) /
                    100 /
                    totalShares[mintStage];
                _shareData[sellerAddresses[i]].shareAmount +=
                    (shareDetails[mintStage][4] * prices[i] * royaltyFee) /
                    100 /
                    totalShares[mintStage];
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
