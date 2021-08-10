pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

// import "./lib/Utils.sol";
// import "./lib/BepLib.sol";
// import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
// import "./lib/IBEP20.sol";
import "./lib/SafeMath.sol";
import "./lib/IPancakeRouter02.sol";

import "./lib/WhitelistUpgradeable.sol";
import "./lib/IStrategy.sol";
// import "./interfaces/IMasterChef.sol";
import "./lib/VaultController.sol";

import {PoolConstant} from "./lib/PoolConstant.sol";

contract AIStaking is OwnableUpgradeable, ReentrancyGuardUpgradeable,VaultController, IStrategy {
    using SafeMath for uint256;

    // address public primaryToken;
    // address public _busdAddress;
    address public BURN_ADDRESS; // = 0x000000000000000000000000000000000000dEaD;

    
    IPancakeRouter02 public pancakeRouter;


    using SafeBEP20 for IBEP20;
    using SafeMath for uint;

    /* ========== CONSTANTS ============= */

    IBEP20 private CAKE ;//= IBEP20(0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82);
    IBEP20 private XBN;// = IBEP20(0x547CBE0f0c25085e7015Aa6939b28402EB0CcDAC);
    IMasterChef private CAKE_MASTER_CHEF;// = IMasterChef(0x73feaa1eE314F8c655E354234017bE2193C9E24E);

    uint public constant override pid = 0;
    PoolConstant.PoolTypes public constant override poolType = PoolConstant.PoolTypes.CakeStake;

    uint private constant DUST = 1000;

    /* ========== STATE VARIABLES ========== */

    uint public totalShares;
    mapping (address => uint) private _shares;
    mapping (address => uint) private _principal;
    mapping (address => uint) private _depositedAt;

    /* ========== INITIALIZER ========== */

    function initialize(address routerAddress) external initializer {
        __VaultController_init(CAKE);

        OwnableUpgradeable.__Ownable_init();
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

        pancakeRouter = IPancakeRouter02(routerAddress);
        CAKE = IBEP20(0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82);
        XBN = IBEP20(0x547CBE0f0c25085e7015Aa6939b28402EB0CcDAC);
        CAKE_MASTER_CHEF = IMasterChef(0x73feaa1eE314F8c655E354234017bE2193C9E24E);

        CAKE.approve(address(CAKE_MASTER_CHEF), 2**256 - 1);
        CAKE.approve(address(pancakeRouter), ~uint(0));
        // XBN.approve(address(pancakeRouter), ~uint(0));

        setBurnAddress(0x000000000000000000000000000000000000dEaD);
        
    }

    /* ========== VIEW FUNCTIONS ========== */

    function totalSupply() external view override returns (uint) {
        return totalShares;
    }

    function balance() public view override returns (uint amount) {
        (amount,) = CAKE_MASTER_CHEF.userInfo(pid, address(this));
    }

    function balanceOf(address account) public view override returns(uint) {
        if (totalShares == 0) return 0;
        return balance().mul(sharesOf(account)).div(totalShares);
    }

    function withdrawableBalanceOf(address account) public view override returns (uint) {
        return balanceOf(account);
    }

    function sharesOf(address account) public view override returns (uint) {
        return _shares[account];
    }

    function principalOf(address account) public view override returns (uint) {
        return _principal[account];
    }

    function earned(address account) public view override returns (uint) {
        if (balanceOf(account) >= principalOf(account) + DUST) {
            return balanceOf(account).sub(principalOf(account));
        } else {
            return 0;
        }
    }

    function priceShare() external view override returns(uint) {
        if (totalShares == 0) return 1e18;
        return balance().mul(1e18).div(totalShares);
    }

    function depositedAt(address account) external view override returns (uint) {
        return _depositedAt[account];
    }

    function rewardsToken() external view override returns (address) {
        return address(_stakingToken);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function swapCakeForXBN(uint amount,address to) public {
        
        address[] memory path = new address[](2);
        path[0] = address(CAKE);
        path[1] = address(XBN);

        // make the swap

        pancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount,
            0, // accept any amount of XBN
            path,
            to,
            block.timestamp + 360
        );
    }

    function deposit(uint _amount) public override {
        _deposit(_amount, msg.sender);

        // if (isWhitelist(msg.sender) == false) 
        {
            // TODO: documenting these 
            _principal[msg.sender] = _principal[msg.sender].add(_amount);
            _depositedAt[msg.sender] = block.timestamp;
        }
    }

    function depositAll() external override {
        deposit(CAKE.balanceOf(msg.sender));
    }

    function withdrawAll() external override {
        uint amount = balanceOf(msg.sender);
        // uint principal = principalOf(msg.sender);
        // uint depositTimestamp = _depositedAt[msg.sender];

        totalShares = totalShares.sub(_shares[msg.sender]);
        delete _shares[msg.sender];
        delete _principal[msg.sender];
        delete _depositedAt[msg.sender];

        uint cakeHarvested = _withdrawStakingToken(amount);

        // uint profit = amount > principal ? amount.sub(principal) : 0;
        // uint withdrawalFee = canMint() ? _minter.withdrawalFee(principal, depositTimestamp) : 0;
        // uint performanceFee = canMint() ? _minter.performanceFee(profit) : 0;

        // if (withdrawalFee.add(performanceFee) > DUST) {
        //     _minter.mintFor(address(CAKE), withdrawalFee, performanceFee, msg.sender, depositTimestamp);
        //     if (performanceFee > 0) {
        //         emit ProfitPaid(msg.sender, profit, performanceFee);
        //     }
        //     amount = amount.sub(withdrawalFee).sub(performanceFee);
        // }

        CAKE.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount, 0);

        _harvest(cakeHarvested);
    }

    function harvest() external override {
        uint cakeHarvested = _withdrawStakingToken(0);
        _harvest(cakeHarvested);
    }

    function withdraw(uint shares) external override onlyWhitelisted {
        uint amount = balance().mul(shares).div(totalShares);
        totalShares = totalShares.sub(shares);
        _shares[msg.sender] = _shares[msg.sender].sub(shares);

        uint cakeHarvested = _withdrawStakingToken(amount);

        // TODO for BNB Version
        // - convert CAKE to BNB
        // - buy more BNB from XBN if needed
        // - send back BNB to msg.sender

        CAKE.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount, 0);

        _harvest(cakeHarvested);
    }

    // @dev underlying only + withdrawal fee + no perf fee
    function withdrawUnderlying(uint _amount) external {
        uint amount = Math.min(_amount, _principal[msg.sender]);
        uint shares = Math.min(amount.mul(totalShares).div(balance()), _shares[msg.sender]);
        totalShares = totalShares.sub(shares);
        _shares[msg.sender] = _shares[msg.sender].sub(shares);
        _principal[msg.sender] = _principal[msg.sender].sub(amount);

        uint cakeHarvested = _withdrawStakingToken(amount);
        // uint depositTimestamp = _depositedAt[msg.sender];
        // uint withdrawalFee = canMint() ? _minter.withdrawalFee(amount, depositTimestamp) : 0;
        // if (withdrawalFee > DUST) {
        //     _minter.mintFor(address(CAKE), withdrawalFee, 0, msg.sender, depositTimestamp);
        //     amount = amount.sub(withdrawalFee);
        // }

        CAKE.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount, 0);

        _harvest(cakeHarvested);
    }

    function getReward() external override {
        uint amount = earned(msg.sender);
        uint shares = Math.min(amount.mul(totalShares).div(balance()), _shares[msg.sender]);
        totalShares = totalShares.sub(shares);
        _shares[msg.sender] = _shares[msg.sender].sub(shares);
        _cleanupIfDustShares();

        uint cakeHarvested = _withdrawStakingToken(amount);
        // uint depositTimestamp = _depositedAt[msg.sender];
        // uint performanceFee = canMint() ? _minter.performanceFee(amount) : 0;
        // if (performanceFee > DUST) {
        //     _minter.mintFor(address(CAKE), 0, performanceFee, msg.sender, depositTimestamp);
        //     amount = amount.sub(performanceFee);
        // }
        
        // CAKE.safeTransfer(msg.sender, amount);
        swapCakeForXBN(amount, msg.sender);

        emit ProfitPaid(msg.sender, amount, 0);

        _harvest(cakeHarvested);
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    function _depositStakingToken(uint amount) private returns(uint cakeHarvested) {
        uint before = CAKE.balanceOf(address(this));
        CAKE_MASTER_CHEF.enterStaking(amount);
        cakeHarvested = CAKE.balanceOf(address(this)).add(amount).sub(before);
    }

    function _withdrawStakingToken(uint amount) private returns(uint cakeHarvested) {
        uint before = CAKE.balanceOf(address(this));
        CAKE_MASTER_CHEF.leaveStaking(amount);
        cakeHarvested = CAKE.balanceOf(address(this)).sub(amount).sub(before);
    }

    function _harvest(uint cakeAmount) private {
        if (cakeAmount > 0) {

            // TODO: burn 33% into XBN on harvest if > 0.5 cake
            if (cakeAmount > 5* 10 ** 17) { // 0.5 cake
                uint burnAmount = cakeAmount.div(3);
                cakeAmount = cakeAmount.sub(burnAmount);
                swapCakeForXBN(burnAmount, BURN_ADDRESS);
            }

            emit Harvested(cakeAmount);
            CAKE_MASTER_CHEF.enterStaking(cakeAmount);
        }
    }

    function _deposit(uint _amount, address _to) private whenNotPaused {
        uint _pool = balance();
        CAKE.safeTransferFrom(msg.sender, address(this), _amount);    

        uint shares = 0;
        if (totalShares == 0) {
            shares = _amount;
        } else {
            shares = (_amount.mul(totalShares)).div(_pool);
        }

        totalShares = totalShares.add(shares);
        _shares[_to] = _shares[_to].add(shares);

        uint cakeHarvested = _depositStakingToken(_amount);
        emit Deposited(msg.sender, _amount);

        _harvest(cakeHarvested);
    }

    function _cleanupIfDustShares() private {
        uint shares = _shares[msg.sender];
        if (shares > 0 && shares < DUST) {
            totalShares = totalShares.sub(shares);
            delete _shares[msg.sender];
        }
    }

    /* ========== SALVAGE PURPOSE ONLY ========== */

    // @dev _stakingToken(CAKE) must not remain balance in this contract. So dev should be able to salvage staking token transferred by mistake.
    function recoverToken(address _token, uint amount) virtual external override onlyOwner {
        IBEP20(_token).safeTransfer(owner(), amount);

        // emit Recovered(_token, amount);
    }


    function setRouter(address payable routerAddress) public onlyOwner {
        pancakeRouter = IPancakeRouter02(routerAddress);
    }
  

    function setBurnAddress(address _burnAddress) public onlyOwner {
        BURN_ADDRESS = _burnAddress;
    }

}
