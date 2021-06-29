pragma solidity >=0.6.8;

import "./BepLib.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";

library Utils {
    using SafeMath for uint256;

    function random(
        uint256 from,
        uint256 to,
        uint256 salty
    ) public view returns (uint256) {
        uint256 seed = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp +
                        block.difficulty +
                        ((
                            uint256(keccak256(abi.encodePacked(block.coinbase)))
                        ) / (now)) +
                        block.gaslimit +
                        ((uint256(keccak256(abi.encodePacked(msg.sender)))) /
                            (now)) +
                        block.number +
                        salty
                )
            )
        );
        return seed.mod(to - from) + from;
    }

    function isLotteryWon(uint256 salty, uint256 winningDoubleRewardPercentage)
        private
        view
        returns (bool)
    {
        uint256 luckyNumber = random(0, 100, salty);
        uint256 winPercentage = winningDoubleRewardPercentage;
        return luckyNumber <= winPercentage;
    }

    function calculateBNBReward(
        // uint256 _tTotal,
        uint256 currentBalance,
        uint256 currentBNBPool,
        uint256 winningDoubleRewardPercentage,
        uint256 _totalSupply
    )
        public
        view
        returns (
            // address ofAddress
            uint256
        )
    {
        uint256 bnbPool = currentBNBPool;

        // calculate reward to send
        bool isLotteryWonOnClaim = isLotteryWon(
            currentBalance,
            winningDoubleRewardPercentage
        );
        uint256 multiplier = 100;

        if (isLotteryWonOnClaim) {
            multiplier = random(150, 200, currentBalance);
        }

        // now calculate reward
        uint256 reward = bnbPool
        .mul(multiplier)
        .mul(currentBalance)
        .div(100)
        .div(_totalSupply);

        return reward;
    }

    function calculateTokenReward(
        //  uint256 _tTotal,
        uint256 currentBalance,
        uint256 currentBNBPool,
        uint256 winningDoubleRewardPercentage,
        uint256 _totalSupply,
        // address ofAddress,
        address routerAddress,
        address tokenAddress
    ) public view returns (uint256) {
        IPancakeRouter02 pancakeRouter = IPancakeRouter02(routerAddress);

        // generate the pancake pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = pancakeRouter.WETH();
        // ETH Address
        // path[1] = address(0xd66c6B4F0be8CE5b39D52E0Fd1344c389929B378);
        path[1] = tokenAddress;

        uint256 bnbReward = calculateBNBReward(
            // _tTotal,
            currentBalance,
            currentBNBPool,
            winningDoubleRewardPercentage,
            _totalSupply
            // ofAddress
        );

        return pancakeRouter.getAmountsOut(bnbReward, path)[1];
    }

    // function calculateBTCReward(
    //     uint256 _tTotal,
    //     uint256 currentBalance,
    //     uint256 currentBNBPool,
    //     uint256 winningDoubleRewardPercentage,
    //     uint256 totalSupply,
    //     address ofAddress,
    //     address routerAddress,
    //     address btcAddress
    // ) public view returns (uint256) {
    //     IPancakeRouter02 pancakeRouter = IPancakeRouter02(routerAddress);

    //     // generate the pancake pair path of token -> weth
    //     address[] memory path = new address[](2);
    //     path[0] = pancakeRouter.WETH();
    //     // ETH Address
    //     // path[1] = address(0xd66c6B4F0be8CE5b39D52E0Fd1344c389929B378);
    //     path[1] = btcAddress;

    //     uint256 bnbReward =
    //         calculateBNBReward(
    //             // _tTotal,
    //             currentBalance,
    //             currentBNBPool,
    //             winningDoubleRewardPercentage,
    //             totalSupply,
    //             ofAddress
    //         );

    //     return pancakeRouter.getAmountsOut(bnbReward, path)[1];
    // }

    function calculateTopUpClaim(
        uint256 currentRecipientBalance,
        uint256 basedRewardCycleBlock,
        uint256 threshHoldTopUpRate,
        uint256 amount
    ) public view returns (uint256) {
        if (currentRecipientBalance == 0) {
            return block.timestamp + basedRewardCycleBlock;
        } else {
            uint256 rate = amount.mul(100).div(currentRecipientBalance);

            if (uint256(rate) >= threshHoldTopUpRate) {
                uint256 incurCycleBlock = basedRewardCycleBlock
                .mul(uint256(rate))
                .div(100);

                if (incurCycleBlock >= basedRewardCycleBlock) {
                    incurCycleBlock = basedRewardCycleBlock;
                }

                return incurCycleBlock;
            }

            return 0;
        }
    }

    function swapTokensForEth(address routerAddress, uint256 tokenAmount)
        public
    {
        IPancakeRouter02 pancakeRouter = IPancakeRouter02(routerAddress);

        // generate the pancake pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = pancakeRouter.WETH();

        // make the swap
        pancakeRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of BNB
            path,
            address(this),
            block.timestamp
        );
    }

    function swapBNBForToken(
        address routerAddress,
        address tokenAddress,
        address recipient,
        uint256 bnbAmount
    ) public {
        IPancakeRouter02 pancakeRouter = IPancakeRouter02(routerAddress);

        // Generate the pancake pair path of token => WETH
        address[] memory path = new address[](2);
        path[0] = pancakeRouter.WETH();
        // path[1] = address(0xd66c6B4F0be8CE5b39D52E0Fd1344c389929B378);
        path[1] = tokenAddress;

        // Swap
        pancakeRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: bnbAmount
        }(0, path, address(recipient), block.timestamp + 360);
    }

    function swapXBNForTokens(
        address routerAddress,
        address tokenAddress,
        address XBNAddress,
        address recipient,
        uint256 ethAmount
    ) public {
        IPancakeRouter02 pancakeRouter = IPancakeRouter02(routerAddress);

        // generate the pancake pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = XBNAddress;
        path[1] = tokenAddress;

        // make the swap
        pancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            ethAmount,
            0,
            path,
            address(recipient),
            block.timestamp + 360
        );
    }

    function addLiquidity(
        address routerAddress,
        address owner,
        uint256 tokenAmount,
        uint256 ethAmount
    ) public {
        IPancakeRouter02 pancakeRouter = IPancakeRouter02(routerAddress);

        // add the liquidity
        pancakeRouter.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner,
            block.timestamp + 360
        );
    }
}
