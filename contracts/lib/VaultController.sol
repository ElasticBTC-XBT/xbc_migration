pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;


// import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/SafeBEP20.sol";
import "./SafeBEP20.sol";
// import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/BEP20.sol";
import "./IBEP20.sol";

import "./IPancakeRouter02.sol";
import "./IPancakePair.sol";
import "./IStrategy.sol";
import "./IMasterChef.sol";
// import "./IBunnyMinterV2.sol";
// import "./IBunnyChef.sol";
import "./WhitelistUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

abstract contract VaultController is IVaultController, PausableUpgradeable, WhitelistUpgradeable {
    using SafeBEP20 for IBEP20;

    /* ========== CONSTANT VARIABLES ========== */
    IBEP20 private constant BUNNY = IBEP20(0xC9849E6fdB743d08fAeE3E34dd2D1bc69EA11a51);

    /* ========== STATE VARIABLES ========== */

    address public keeper;
    IBEP20 internal _stakingToken;
    // IBunnyMinterV2 internal _minter;
    // IBunnyChef internal _bunnyChef;

    /* ========== VARIABLE GAP ========== */

    uint256[49] private __gap;

    /* ========== Event ========== */

    event Recovered(address token, uint amount);


    /* ========== MODIFIERS ========== */

    modifier onlyKeeper {
        require(msg.sender == keeper || msg.sender == owner(), 'VaultController: caller is not the owner or keeper');
        _;
    }

    /* ========== INITIALIZER ========== */

    function __VaultController_init(IBEP20 token) internal initializer {
        // __PausableUpgradeable_init();
        __Pausable_init();
        __WhitelistUpgradeable_init();

        keeper = 0x793074D9799DC3c6039F8056F1Ba884a73462051;
        _stakingToken = token;
    }

    // /* ========== VIEWS FUNCTIONS ========== */

    // function minter() external view override returns (address) {
    //     return canMint() ? address(_minter) : address(0);
    // }

    // function canMint() internal view returns (bool) {
    //     return address(_minter) != address(0) && _minter.isMinter(address(this));
    // }

    // function bunnyChef() external view override returns (address) {
    //     return address(_bunnyChef);
    // }

    function stakingToken() external view override returns (address) {
        return address(_stakingToken);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function setKeeper(address _keeper) external onlyKeeper {
        require(_keeper != address(0), 'VaultController: invalid keeper address');
        keeper = _keeper;
    }

    // function setMinter(address newMinter) virtual public onlyOwner {
    //     // can zero
    //     _minter = IBunnyMinterV2(newMinter);
    //     if (newMinter != address(0)) {
    //         require(newMinter == BUNNY.getOwner(), 'VaultController: not bunny minter');
    //         _stakingToken.safeApprove(newMinter, 0);
    //         _stakingToken.safeApprove(newMinter, ~uint(0));
    //     }
    // }

    // function setBunnyChef(IBunnyChef newBunnyChef) virtual public onlyOwner {
    //     require(address(_bunnyChef) == address(0), 'VaultController: setBunnyChef only once');
    //     _bunnyChef = newBunnyChef;
    // }

    /* ========== SALVAGE PURPOSE ONLY ========== */

    function recoverToken(address _token, uint amount) virtual external onlyOwner {
        require(_token != address(_stakingToken), 'VaultController: cannot recover underlying token');
        IBEP20(_token).safeTransfer(owner(), amount);

        emit Recovered(_token, amount);
    }
}