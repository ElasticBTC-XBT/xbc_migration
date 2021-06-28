pragma solidity >=0.6.8;
pragma experimental ABIEncoderV2;

import "./lib/Utils.sol";

interface XBN is IBEP20 {
    function getNextAvailableClaimTime(address account)
        external
        view
        returns (uint256);

    function setNextAvailableClaimTime(address account) external;
}

contract ClaimReward {
    using SafeMath for uint256;

    XBN public tokenInstance;

    address private owner;
    address payable private foundationAddress;
    address public primaryToken;
    address public _busdAddress;
    address constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 public rewardThreshold;
    IPancakeRouter02 public pancakeRouter;
    IPancakePair public pancakePair;

    uint256 bonusRate = 2;
    uint256 public winningDoubleRewardPercentage;

    event ClaimBNBSuccessfully(address, uint256, uint256);

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Error: Only owner can handle this operation ;)"
        );
        _;
    }

    constructor(
        address _tokenInstance,
        address payable routerAddress,
        address payable _foundationAddress
    ) public {
        // set owner
        owner = msg.sender;

        // set token instance
        setPrimaryToken(_tokenInstance);

        // set foundation address
        setFoundationAddress(_foundationAddress);

        // pancake router binding
        setRouter(routerAddress);
        winningDoubleRewardPercentage = 1;
    }

    function setFoundationAddress(address payable _foundationAddress)
        public
        onlyOwner
    {
        require(
            _foundationAddress != address(0),
            "Error: cannot add address at NoWhere :)"
        );
        foundationAddress = _foundationAddress;
    }

    function setPrimaryToken(address tokenAddress) public onlyOwner {
        // set distribution token address
        require(
            tokenAddress != address(0),
            "Error: cannot add token at NoWhere :)"
        );
        tokenInstance = XBN(tokenAddress);
        primaryToken = tokenAddress;
    }

    function setOwner(address newOwner) public onlyOwner {
        owner = newOwner;
    }

    function setBonusRate(uint256 _bonusRate) public onlyOwner {
        bonusRate = _bonusRate;
    }

    function setRewardThreshold(uint256 _rewardThreshold) public onlyOwner {
        rewardThreshold = _rewardThreshold;
    }

    function setRouter(address payable routerAddress) public onlyOwner {
        pancakeRouter = IPancakeRouter02(routerAddress);

        address factory = pancakeRouter.factory();
        address pairAddress = IPancakeFactory(factory).getPair(
            address(primaryToken),
            address(pancakeRouter.WETH())
        );

        pancakePair = IPancakePair(pairAddress);
    }

    function getNextClaimTime(address account) public view returns (uint256) {
        return tokenInstance.getNextAvailableClaimTime(account);
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
            address(this).balance,
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
            // Burn 10% if claim BUSD
            if (tokenAddress == _busdAddress) {
                tokenInstance.transfer(
                    0x000000000000000000000000000000000000dEaD,
                    reward.div(10)
                );
                reward = reward.sub(reward.div(10));
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
            Utils.swapBNBForToken(
                address(pancakeRouter),
                tokenAddress,
                address(msg.sender),
                reward
            );
        } else {
            tokenInstance.transfer(address(msg.sender), reward);
        }
    }

    function claimBNBReward() public {
        claimTokenReward(pancakeRouter.WETH(), true);
    }

    function claimXBNReward() public {
        claimTokenReward(primaryToken, false);
    }

    function claimBUSDReward() public {
        claimTokenReward(_busdAddress, true);
    }
}
