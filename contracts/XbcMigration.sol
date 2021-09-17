pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

// import "./lib/Utils.sol";
// import "./lib/BepLib.sol";
// import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./lib/IBEP20.sol";
import "./lib/SafeBEP20.sol";
import "./lib/SafeMath.sol";
import "./lib/IPancakeRouter02.sol";

import "./lib/WhitelistUpgradeable.sol";

contract XbcMigration is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeMath for uint256;


    using SafeBEP20 for IBEP20;
    using SafeMath for uint;

    /* ========== CONSTANTS ============= */

    IBEP20 public PEPE ;//= IBEP20(0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82);
    IBEP20 public XBN;// = IBEP20(0x547CBE0f0c25085e7015Aa6939b28402EB0CcDAC);
    IBEP20 public XBC;// = IBEP20(0x547CBE0f0c25085e7015Aa6939b28402EB0CcDAC);
    IBEP20 public WBNB;// = IBEP20(0x547CBE0f0c25085e7015Aa6939b28402EB0CcDAC);
    IPancakeRouter02 public pancakeRouter;
    uint public maxMigrationSize;
    uint public OneBNBtoXBCRate;
    /* ========== INITIALIZER ========== */

    function initialize() external initializer {


        OwnableUpgradeable.__Ownable_init();
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

        pancakeRouter = IPancakeRouter02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        
        PEPE = IBEP20(0x0c1b3983D2a4Aa002666820DE5a0B43293291Ea6);
        XBC = IBEP20(0x0321394309CaD7E0E424650844c3AB3b659315d3);
        XBN = IBEP20(0x547CBE0f0c25085e7015Aa6939b28402EB0CcDAC);
        WBNB = IBEP20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);

        maxMigrationSize = 500 * 10 ** 18;
        OneBNBtoXBCRate = 1500 * 10 ** 9 * 10 ** 9;     
        
    }

    function approveAll() public {
        PEPE.approve(address(pancakeRouter), ~uint(0));
        XBC.approve(address(pancakeRouter), ~uint(0));
        XBC.approve(address(0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F), ~uint(0)); //v1
        XBN.approve(address(pancakeRouter), ~uint(0));
        WBNB.approve(address(pancakeRouter), ~uint(0));
    }


    function setOneBNBtoXBCRate(uint rate) public onlyOwner{
        OneBNBtoXBCRate = rate * 10 ** 9;
    }

    function OneBNBtoXBNRate() public view returns (uint){

        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(XBN); 

        return pancakeRouter.getAmountsOut(10** 18, path)[1];
    }


    function getOneBNBtoXBCRate() public view returns (uint){

        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(XBC); 

        return pancakeRouter.getAmountsOut(10** 18, path)[1];
    }

    function setMaxMigrationSize(uint size) public onlyOwner{
        maxMigrationSize = size;
    }

  
    /* ========== MUTATIVE FUNCTIONS ========== */
    function migrate() public {

        uint xbcSize = XBC.balanceOf(msg.sender);

        if ( xbcSize > maxMigrationSize){
            xbcSize = maxMigrationSize;
            
        }

        // to avoid tax
        XBC.transferFrom(msg.sender, address(this), xbcSize);

        // convert to WBNB
        uint wbnbBalanceBefore = WBNB.balanceOf(address(this));
        swapTokenForV1(xbcSize, address(XBC), address(WBNB), address(this));
        uint wbnbAmount = WBNB.balanceOf(address(this)) - wbnbBalanceBefore;

        uint pepeWbnbSize = wbnbAmount/2;        

        //swap and transfer PePe
        swapTokenFor(pepeWbnbSize, address(WBNB), address(PEPE) , msg.sender);

        //transfer XBN
        
        // uint xbcRemain = xbcSize/2;
        // uint xbnAmountToTransfer = xbcRemain   * OneBNBtoXBNRate() / OneBNBtoXBCRate *  115 /100 + 4 * 10 ** 18; // bonus 15% XBN + 4 XBN
        // uint xbnAmountToTransfer =  pepeWbnbSize.mul(OneBNBtoXBNRate()).mul(12).div(10) + 4 * 10 ** 18; // bonus 20% XBN + 4 XBN
        address[] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(XBN); 

        uint xbnAmountToTransfer = pancakeRouter.getAmountsOut(pepeWbnbSize, path)[1];
        xbnAmountToTransfer = xbnAmountToTransfer*120/100 + 4 *  10 ** 8; // bonus 20% XBN + 4 XBN
        XBN.transferFrom(0xAfaB058b3798D49562fEe9d366e293AD881b6968, msg.sender, xbnAmountToTransfer);

        //add liquidity
        uint currentWbnbBalance = WBNB.balanceOf(address(this));
        if (currentWbnbBalance > 5* 10 ** 17){ // 0.5 BNB
            addliquid(currentWbnbBalance);           

        }
        
    }

    function addliquid(uint currentWbnbBalance) public {

        uint xbnBalanceBefore = XBN.balanceOf(address(this));
        swapTokenFor(currentWbnbBalance/2, address(WBNB), address(XBN) , address(this));
        uint xbnAmount = XBN.balanceOf(address(this)) - xbnBalanceBefore;


        pancakeRouter.addLiquidity(
            address(WBNB),
            address(XBN),
            currentWbnbBalance - currentWbnbBalance/2,
            xbnAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(this),
            block.timestamp + 360
            
        );
    }

    function swapTokenFor(uint amount, address fromToken, address toToken, address to) public {
        
        address[] memory path = new address[](2);
        path[0] = address(fromToken);
        path[1] = address(toToken); 
        
        // make the swap
        pancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount,
            0, // accept any amount of XBN
            path,
            to,
            block.timestamp + 360
        );
    }

    function swapTokenForV1(uint amount, address fromToken, address toToken, address to) public {
        
        address[] memory path = new address[](2);
        path[0] = address(fromToken);
        path[1] = address(toToken); 

        IPancakeRouter02 pancakeRouterV1 = IPancakeRouter02(0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F);
        
        // make the swap
        pancakeRouterV1.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount,
            0, // accept any amount of XBN
            path,
            to,
            block.timestamp + 360
        );
    }


    /* ========== SALVAGE PURPOSE ONLY ========== */

    // @dev _stakingToken(CAKE) must not remain balance in this contract. So dev should be able to salvage staking token transferred by mistake.
    function recoverToken(address _token, uint amount) public onlyOwner {
        IBEP20(_token).safeTransfer(owner(), amount);

        // emit Recovered(_token, amount);
    }

    // @dev _stakingToken(CAKE) must not remain BNB balance in this contract. So dev should be able to salvage BNB transferred by mistake.
    function emergencyBNBWithdraw() public onlyOwner {
        (bool sent,) = (address(msg.sender)).call{value : address(this).balance}("");
        require(sent, 'Error: Cannot withdraw');

    }


    function setRouter(address payable routerAddress) public onlyOwner {
        pancakeRouter = IPancakeRouter02(routerAddress);
    }
  


}
