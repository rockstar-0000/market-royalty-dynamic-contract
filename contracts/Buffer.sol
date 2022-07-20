// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract Buffer is Initializable {
    uint256 public totalReceived;

    struct ShareData {
        uint256 shareAmount;
        uint256 lastBlockNumber;
    }

    mapping(address => mapping(address => ShareData)) public _shareData;
    mapping(address => mapping(uint256 => address)) public _creatorPairInfo;

    mapping(address => uint256) public withdrawn;

    uint256 private totalFeeOwners;

    address public NFTAddress;
    uint256 public totalShares = 0;
    address public curator;
    mapping(uint256 => address) public partnersGroup;
    uint256 private partnersGroupLength = 0;
    mapping(uint256 => address) public creatorsGroup;
    uint256 private creatorsGroupLength = 0;
    mapping(uint256 => uint256) public share;
    uint256 private shareLength = 0;
    address private marketWallet = 0x13f41aa17Bf27d9d18910683b8fF61Eb8c992855;

    // event Log(string message);

    function initialize(
        address _curator,
        address[] memory _partnersGroup,
        address[] memory _creatorsGroup,
        address _NFTAddress,
        uint256[] memory _shares
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

        NFTAddress = _NFTAddress;
    }

    // update creator pair info
    function updateCreatorPairInfo(
        address[] memory creators,
        uint256[] memory tokenIDs
    ) external {
        for (uint256 i = 0; i < creators.length; i++) {
            _creatorPairInfo[NFTAddress][tokenIDs[i]] = creators[i];
        }
    }

    receive() external payable {
        totalReceived += msg.value;

        totalFeeOwners += (msg.value * share[5]) / totalShares;

        // Marketplace Calculation
        _shareData[NFTAddress][marketWallet].shareAmount +=
            (msg.value * share[6]) /
            totalShares;

        // Curator Calculation
        _shareData[NFTAddress][curator].shareAmount +=
            (msg.value * share[0]) /
            totalShares;

        // partnersGroup Calculation
        for (uint256 i = 0; i < partnersGroupLength; i++) {
            _shareData[NFTAddress][partnersGroup[i]].shareAmount +=
                (msg.value * share[1]) /
                partnersGroupLength /
                totalShares;
        }

        // creatorsGroup Calculation
        for (uint256 i = 0; i < creatorsGroupLength; i++) {
            _shareData[NFTAddress][creatorsGroup[i]].shareAmount +=
                (msg.value * share[2]) /
                creatorsGroupLength /
                totalShares;
        }
    }

    // Get the last block number
    function getBlockNumber(address account) external view returns (uint256) {
        return _shareData[NFTAddress][account].lastBlockNumber;
    }

    // Set claimable flag
    // function setClaimable(bool _claimable) external {
    //     claimable = _claimable;
    // }

    // Set Marketplace Wallet
    function updateMarketplaceWallet(address _marketWallet) external {
        marketWallet = _marketWallet;
    }

    // Withdraw
    function withdraw(
        address account,
        address[] memory sellerAddresses,
        uint256[] memory tokenIDs,
        uint256[] memory prices,
        uint256 blocknumber,
        address[] memory owners
    ) external payable {
        _shareData[NFTAddress][account].lastBlockNumber = blocknumber;
        uint256 leng = tokenIDs.length;
        for (uint256 i = 0; i < leng; i++) {
            _shareData[NFTAddress][_creatorPairInfo[NFTAddress][tokenIDs[i]]]
                .shareAmount += (share[3] * prices[i] * 10) / 100 / totalShares;
            _shareData[NFTAddress][sellerAddresses[i]].shareAmount +=
                (share[4] * prices[i] * 10) /
                100 /
                totalShares;
        }
        // OwnersGroup Calculation
        uint256 ownerLength = owners.length;
        for (uint256 i = 0; i < ownerLength; i++) {
            _shareData[NFTAddress][owners[i]].shareAmount +=
                totalFeeOwners /
                ownerLength;
        }
        totalFeeOwners = 0;
        // 2. calculate amount to withdraw based on "amount" (out of 1,000,000,000,000)
        require(
            _shareData[NFTAddress][account].shareAmount > 0,
            "Claim is not allowed as of now due to the 0 balance. Please check it later"
        );
        if (_shareData[NFTAddress][account].shareAmount > 0) {
            withdrawn[account] += _shareData[NFTAddress][account].shareAmount;
            _transfer(account, _shareData[NFTAddress][account].shareAmount);
            _shareData[NFTAddress][account].shareAmount = 0;
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
