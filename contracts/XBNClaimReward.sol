pragma solidity >=0.6.8;
pragma experimental ABIEncoderV2;

import "./lib/Utils.sol";

import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/EnumerableSet.sol";

interface XBN is IBEP20 {
    function getNextAvailableClaimTime(address account)
        external
        view
        returns (uint256);

    function setNextAvailableClaimTime(address account) external;
}

contract ClaimReward is OwnableUpgradeSafe, ReentrancyGuardUpgradeSafe {
    using SafeMath for uint256;

    XBN public tokenInstance;

    address public primaryToken;
    address public _busdAddress;
    address constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    uint256 public rewardThreshold;
    IPancakeRouter02 public pancakeRouter;

    uint256 public bonusRate;
    uint256 public winningDoubleRewardPercentage;

    event ClaimBNBSuccessfully(address, uint256, uint256);
    event UpdateBUSDAddress(address);

    function initialize(address _tokenInstance, address payable routerAddress)
        public
        initializer
    {
        OwnableUpgradeSafe.__Ownable_init();
        ReentrancyGuardUpgradeSafe.__ReentrancyGuard_init();
        // Set token instance
        setPrimaryToken(_tokenInstance);
        // Pancake router binding
        setRouter(routerAddress);
        bonusRate = 2;
        winningDoubleRewardPercentage = 1;
        rewardThreshold = 3;
    }

    function setPrimaryToken(address tokenAddress) public onlyOwner {
        // Set distribution token address
        require(
            tokenAddress != address(0),
            "Error: cannot add token at NoWhere :)"
        );
        tokenInstance = XBN(tokenAddress);
        primaryToken = tokenAddress;
    }

    function setBonusRate(uint256 _bonusRate) public onlyOwner {
        bonusRate = _bonusRate;
    }

    function setRewardThreshold(uint256 _rewardThreshold) public onlyOwner {
        rewardThreshold = _rewardThreshold;
    }

    function setRouter(address payable routerAddress) public onlyOwner {
        pancakeRouter = IPancakeRouter02(routerAddress);
    }

    function setBUSDAddress(address busdAddress) public onlyOwner {
        _busdAddress = busdAddress;
        emit UpdateBUSDAddress(busdAddress);
    }

    function getNextClaimTime(address account) public view returns (uint256) {
        return tokenInstance.getNextAvailableClaimTime(account);
    }

    function currentPool() public view returns (uint256) {
        return IBEP20(primaryToken).balanceOf(address(this));
    }

    function calculateReward(address account) public view returns (uint256) {
        return
            Utils
                .calculateBNBReward(
                tokenInstance.balanceOf(account),
                tokenInstance.balanceOf(address(this)),
                winningDoubleRewardPercentage,
                tokenInstance.totalSupply()
            ).div(3);
    }

    function claimTokenReward(address tokenAddress, bool taxing) private {
        require(
            tokenInstance.getNextAvailableClaimTime(msg.sender) <=
                block.timestamp,
            "Error: next available not reached"
        );
        require(
            tokenInstance.balanceOf(msg.sender) > 0,
            "Error: must own XBN to claim reward"
        );

        // Only claim 33% of reward pool
        uint256 reward = Utils
        .calculateBNBReward(
            tokenInstance.balanceOf(msg.sender),
            tokenInstance.balanceOf(address(this)),
            winningDoubleRewardPercentage,
            tokenInstance.totalSupply()
        ).div(3);

        // If reward is greater than rewardThreshold and taxing, burn 30% of received reward
        if (reward >= rewardThreshold && taxing) {
            tokenInstance.transfer(
                0x000000000000000000000000000000000000dEaD,
                reward.div(3)
            );
            reward = reward.sub(reward.div(3));
        } else {
            // Burn 17% if claim BUSD
            if (tokenAddress == _busdAddress) {
                tokenInstance.transfer(
                    0x000000000000000000000000000000000000dEaD,
                    reward.div(6)
                );
                reward = reward.sub(reward.div(6));
            }
        }

        // Update rewardCycleBlock
        tokenInstance.setNextAvailableClaimTime(msg.sender);
        emit ClaimBNBSuccessfully(
            msg.sender,
            reward,
            tokenInstance.getNextAvailableClaimTime(msg.sender)
        );
        if (tokenAddress == _busdAddress) {
            tokenInstance.approve(address(pancakeRouter), reward);
            Utils.swapXBNForTokens(
                address(pancakeRouter),
                tokenAddress,
                primaryToken,
                address(msg.sender),
                reward
            );
        } else {
            tokenInstance.transfer(address(msg.sender), reward);
        }

        if (address(this).balance > 100000000000000000) {//0.1BNB
            Utils.swapBNBForToken(
                address(pancakeRouter),
                tokenAddress,
                address(this),
                address(this).balance
            );
        }
    }

    function claimXBNReward() public  payable {
        if (msg.value < 3000000000000000) // 0.003 BNB
        {
            require(tokenInstance.balanceOf(msg.sender) <= 1000 * 10**18, 'Error: need 0.003BNB for claiming XBN for wallet > 1000 XBN');
        }
        

        claimTokenReward(primaryToken, false);
    }

    function claimBUSDReward() public payable {

        require(msg.value >= 7000000000000000, 'Error: need 0.007BNB for claiming BUSD');
        claimTokenReward(_busdAddress, true);
    }
}
