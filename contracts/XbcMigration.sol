pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./lib/IBEP20.sol";
import "./lib/SafeBEP20.sol";
import "./lib/SafeMath.sol";
import "./lib/IPancakeRouter02.sol";
import "./lib/IPancakePair.sol";

import "./lib/WhitelistUpgradeable.sol";



// helper methods for interacting with ERC20 tokens and sending ETH that do not consistently return true/false
library TransferHelper {
    function safeApprove(
        address token,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'TransferHelper::safeApprove: approve failed'
        );
    }

    function safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'TransferHelper::safeTransfer: transfer failed'
        );
    }

    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'TransferHelper::transferFrom: transferFrom failed'
        );
    }

    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, 'TransferHelper::safeTransferETH: ETH transfer failed');
    }
}


interface IPancakeFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;

    function INIT_CODE_PAIR_HASH() external view returns (bytes32);
}

library PancakeLibrary {
    using SafeMath for uint;

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal view returns (address token0, address token1) {
        require(tokenA != tokenB, 'PancakeLibrary: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'PancakeLibrary: ZERO_ADDRESS');
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address factory, address tokenA, address tokenB) internal view returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);

      
        pair = address(uint160(uint(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                
                hex'00fb7f630766e6a796048ea87d01acd3068e8ff67d078148a3fa3f4a84f69bd5' // init code hash: mainnet v2
            )))));
    }
    //hex'00fb7f630766e6a796048ea87d01acd3068e8ff67d078148a3fa3f4a84f69bd5' // init code hash: mainnet
    //hex'd0d4c4cd0848c93cb4fd1f498d7013ee6bfb25783ea21593d5834f5d250ece66' // init code hash: testnet

    // fetches and sorts the reserves for a pair
    function getReserves(address factory, address tokenA, address tokenB) internal view returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        pairFor(factory, tokenA, tokenB);
        (uint reserve0, uint reserve1,) = IPancakePair(pairFor(factory, tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, 'PancakeLibrary: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'PancakeLibrary: INSUFFICIENT_LIQUIDITY');
        amountB = amountA.mul(reserveB) / reserveA;
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        require(amountIn > 0, '322 PancakeLibrary: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'PancakeLibrary: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn.mul(9975);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(10000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns (uint amountIn) {
        require(amountOut > 0, 'PancakeLibrary: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'PancakeLibrary: INSUFFICIENT_LIQUIDITY');
        uint numerator = reserveIn.mul(amountOut).mul(10000);
        uint denominator = reserveOut.sub(amountOut).mul(9975);
        amountIn = (numerator / denominator).add(1);
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(address factory, uint amountIn, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'PancakeLibrary: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i; i < path.length - 1; i++) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(address factory, uint amountOut, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'PancakeLibrary: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint i = path.length - 1; i > 0; i--) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }
}


contract XbcMigration is OwnableUpgradeable, ReentrancyGuardUpgradeable  {
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


    uint public bonusRate;
    mapping(address => uint256) public nextClaimTime;
    mapping(address => uint256) public reward;
    uint public claimPeriod;


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

    function setBonusRate(uint rate) public onlyOwner{
        bonusRate = rate;
    }

    function setClaimPeriod(uint _minutes) public onlyOwner{
        claimPeriod = _minutes;
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
    function _swap(uint[] memory amounts, address[] memory path, address _to, address factory) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = PancakeLibrary.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? PancakeLibrary.pairFor(factory, output, path[i + 2]) : _to;
            IPancakePair(PancakeLibrary.pairFor(factory, input, output)).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }
    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to,address factory) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = PancakeLibrary.sortTokens(input, output);
            IPancakePair pair = IPancakePair(PancakeLibrary.pairFor(factory, input, output));
            uint amountInput;
            uint amountOutput;
            { // scope to avoid stack too deep errors
            (uint reserve0, uint reserve1,) = pair.getReserves();
            (uint reserveInput, uint reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
            amountInput = IBEP20(input).balanceOf(address(pair)).sub(reserveInput);
            amountOutput = PancakeLibrary.getAmountOut(amountInput, reserveInput, reserveOutput);
            }
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
            address to = i < path.length - 2 ? PancakeLibrary.pairFor(factory, output, path[i + 2]) : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    function migrateFrom(address fromTokenAdress, address ref) public {

        IBEP20 fromToken = IBEP20(fromTokenAdress);

        require(fromTokenAdress!=0x27a339d9B59b21390d7209b78a839868E319301B, "Can not migrate xBlade");
        require(fromTokenAdress!=0x0c1b3983D2a4Aa002666820DE5a0B43293291Ea6, "Can not migrate Pepe");

        uint tokenBalance = fromToken.balanceOf(msg.sender);
        uint beforeXBNBalance = XBN.balanceOf(msg.sender);

        address[] memory path1 = new address[](2);
        path1[0] = address(WBNB);
        path1[1] = fromTokenAdress; 

        uint _maxMigrationSize = pancakeRouter.getAmountsOut(20 * 10** 18, path1)[1]; // maxMigrationSize = 20 BNB

        
        if ( tokenBalance > _maxMigrationSize){
            tokenBalance = _maxMigrationSize;
            
        }
        address factory = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;// pancake v2 factory
        
        // BEGIN override swapExactTokensForTokens
        address[] memory path2 = new address[](3);
        path2[0] = address(fromToken);
        path2[1] = address(WBNB); 
        path2[2] = address(XBN);

        // uint[] memory amounts = PancakeLibrary.getAmountsOut(factory, tokenBalance, path2);    
        address tokenFromWBNBPool = PancakeLibrary.pairFor(factory, fromTokenAdress, address(WBNB));  
        // transfer directly token from msg.sender into Pool to save fee & tax
        TransferHelper.safeTransferFrom(
            fromTokenAdress, msg.sender, tokenFromWBNBPool, tokenBalance
        );
        
        _swapSupportingFeeOnTransferTokens( path2, msg.sender, factory);

        // END override swapExactTokensForTokens

        uint afterXBNBalance = XBN.balanceOf(msg.sender);
        uint bonus = (afterXBNBalance - beforeXBNBalance).div(100).mul(bonusRate);

        

        // if (ref != address(0) && ref != msg.sender){
        if (ref != address(0) && ref != msg.sender){

            //address[] memory path1 = new address[](2);
            path1[0] = address(WBNB);
            path1[1] = address(XBN);

            uint bonusSize = pancakeRouter.getAmountsOut(178 * 10** 12, path1)[1]; // 0.001388 BNB for Fee

            XBN.transfer(ref, bonusSize);
            reward[ref] = reward[ref] + bonus/4; // 1/4 of bonus, which is 5% of total 
            
            nextClaimTime[ref] = nextClaimTime[ref] +  60; // 1 minute
        } 
        
        bonus = bonus.div(4).mul(3); // 3/4 of bonus, which is 15% of total
        reward[msg.sender] = reward[msg.sender] + bonus;
        nextClaimTime[msg.sender] = block.timestamp + claimPeriod * 60;
    }

    function claimBonus() public {

        require(nextClaimTime[msg.sender] < block.timestamp, "You can't claim bonus before claim period");
        require(reward[msg.sender] >0, "You do not have bonus left");

        uint amount = 0;

        if (reward[msg.sender] > 300 * 10 ** 18){ // 300 XBN , claim 17%
            amount = reward[msg.sender]/6;
        } else{
            amount = reward[msg.sender]/3; // claim 33%
        }

        if (reward[msg.sender] < 30 * 10 ** 18){
            amount = reward[msg.sender]/2; // claim 50%
        } 
        if (reward[msg.sender] < 10* 10 ** 18){
            amount = reward[msg.sender]; // claim 100%
        } 

        reward[msg.sender] = reward[msg.sender].sub(amount);
        nextClaimTime[msg.sender] = block.timestamp + claimPeriod * 60; // 24 hours


        XBN.transfer(msg.sender, amount);
    }

    function getBonus(address holder) public view returns (uint){
        return reward[holder];
    }

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
        xbnAmountToTransfer = xbnAmountToTransfer*120/100 + 4 *  10 ** 18; // bonus 20% XBN + 4 XBN
        XBN.transferFrom(0xAfaB058b3798D49562fEe9d366e293AD881b6968, msg.sender, xbnAmountToTransfer);

        //add liquidity
        uint currentWbnbBalance = WBNB.balanceOf(address(this));
        if (currentWbnbBalance > 2 * 10 ** 17){ // 0.5 BNB
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

    function withdrawErc20(address tokenAddress, uint256 amount)
        public
        onlyOwner
    {
        IBEP20 _tokenInstance = IBEP20(tokenAddress);
        _tokenInstance.transfer(msg.sender, amount * 10**18);
    }

}
