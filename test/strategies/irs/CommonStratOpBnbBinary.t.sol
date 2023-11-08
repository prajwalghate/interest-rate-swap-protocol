pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../../src/strategies/irs/EarthLpStaking.sol";
import "../../../src/strategies/irs/CommonStrat.sol";
import "../../../src/strategies/common/interfaces/IStrategy.sol";
import "../../../src/vaults/EarthAutoCompoundingVaultPublic.sol";
import "@openzeppelin/token/ERC20/IERC20.sol";

///@dev
///As there is dependency on Cake swap protocol. Replicating the protocol deployment on separately is difficult. Hence we would test on main net fork of BSC.
///The addresses used below must also be mainnet addresses.

contract EarthLpStakingTest is Test {
    EarthLpStaking parentStrategy;
    EarthAutoCompoundingVaultPublic parentVault;
    CommonStrat asset0Strategy;
    EarthAutoCompoundingVaultPublic asset0Vault;
    CommonStrat asset1Strategy;
    EarthAutoCompoundingVaultPublic asset1Vault;

    //Events
    event StratHarvest(
        address indexed harvester,
        uint256 stakeHarvested,
        uint256 tvl
    );
    event Deposit(uint256 tvl, uint256 amount);
    event Withdraw(uint256 tvl, uint256 amount);

    ///@dev Required addresses from mainnet
    ///@notice Currrent addresses are for the BUSD-WOM pool
    //TODO: move these address configurations to an external file and keep it editable and configurable
    address _stake = 0x506B8322E1159d06E493EBe7ffA41a24291e7Ae3; //Mainnet address of the LP Pool you're deploying funds to. It is also the ERC20 token contract of the LP token.
    uint256 _poolId = 2; //In Pancake swap every Liquidity Pool has a pool id. This is the pool id of the LP pool we're testing.
    address _chef = 0x39a786421889EB581bd105508a0D2Dc03523B903; //Address of the pancake master chef v2 contract on BSC mainnet
    address _router = 0x3958795ca5C4d9f7Eb55656Ba664efA032E1357b; //Address of Pancake Swap router
    address _reward = 0xa41B3067eC694DBec668c389550bA8fc589e5797; //Adress of the CAKE ERC20 token on mainnet
    address _lp0Token = 0x4200000000000000000000000000000000000006; //Address of wrapped version of BNB which is the native token of BSC
    address _lp1Token = 0xa41B3067eC694DBec668c389550bA8fc589e5797;

    address[] _rewardToNativeRoute = new address[](2);
    address[] _rewardToLp0Route = new address[](2);
    address[] _rewardToLp1Route = new address[](2);

    ///@dev Vault Params
    ///@notice Can be configured according to preference
    string rivTokenName = "Riv CakeV2 WOM-BUSD";
    string rivTokenSymbol = "rivCakeV2WOM-BUD";
    uint256 stratUpdateDelay = 21600;
    uint256 vaultTvlCap = 10000e18;

    ///@dev Users Setup
    address _user = 0xbA79a22A4b8018caFDC24201ab934c9AdF6903d7;
    address _manager = 0xbA79a22A4b8018caFDC24201ab934c9AdF6903d7;
    address _other = 0xF18Bb60E7Bd9BD65B61C57b9Dd89cfEb774274a1;
    address _whale = 0xF172946a475afB2e8b4B630881945D1412E54bd9;
    address _whaleLp1Token = 0x74d0116552c7a52059B12c0d251976a3405C7806;
    address _whaleLp0Token = 0x1D6A6A62eaae713F96372e212eb37F1612353B23;
    address _factory = 0xd50aaE6C73E2486B0Da718D23F35Dcf5aad25911;

    function setUp() public {
        ///@dev creating the routes
        _rewardToNativeRoute[0] = _reward;
        _rewardToNativeRoute[1] = _lp0Token;

        _rewardToLp0Route[0] = _reward;
        _rewardToLp0Route[1] = _lp0Token;

        _rewardToLp1Route[0] = _reward;
        _rewardToLp1Route[1] = _lp1Token;

        ///@dev all deployments will be made by the user
        vm.startPrank(_user);

        ///@dev Initializing the vault with invalid strategy
        parentVault = new EarthAutoCompoundingVaultPublic(
            _stake,
            rivTokenName,
            rivTokenSymbol,
            stratUpdateDelay,
            vaultTvlCap
        );
        asset0Vault = new EarthAutoCompoundingVaultPublic(
            _lp0Token,
            rivTokenName,
            rivTokenSymbol,
            stratUpdateDelay,
            vaultTvlCap
        );

        asset1Vault = new EarthAutoCompoundingVaultPublic(
            _lp1Token,
            rivTokenName,
            rivTokenSymbol,
            stratUpdateDelay,
            vaultTvlCap
        );

        ///@dev Initializing the strategy
        CommonAddresses memory _commonAddresses = CommonAddresses(
            address(parentVault),
            _router
        );
        EarthLpStakingParams memory earthLpStakingParams = EarthLpStakingParams(
            _stake,
            _poolId,
            _chef,
            _rewardToLp0Route,
            _rewardToLp1Route,
            // _lp1Token,
            _lp0Token,
            _factory
        );
        parentStrategy = new EarthLpStaking(
            earthLpStakingParams,
            _commonAddresses
        );
        asset0Strategy = new CommonStrat(
            address(asset0Vault),
            address(parentStrategy),
            5,
            1000
        );
        asset1Strategy = new CommonStrat(
            address(asset1Vault),
            address(parentStrategy),
            10,
            1000
        );
        vm.stopPrank();

        vm.prank(_factory);
        parentVault.init(IStrategy(address(parentStrategy)));
        asset0Vault.init(IStrategy(address(asset0Strategy)));
        asset1Vault.init(IStrategy(address(asset1Strategy)));

        uint256 balanceOfWhale = IERC20(_stake).balanceOf(_whale);
        ///@dev Transfering LP tokens from a whale to my accounts
        vm.startPrank(_whale);
        IERC20(_stake).transfer(_user, balanceOfWhale / 3);
        IERC20(_stake).transfer(_other, balanceOfWhale / 3);
        vm.stopPrank();

        balanceOfWhale = IERC20(_lp1Token).balanceOf(_whaleLp1Token);
        vm.startPrank(_whaleLp1Token);
        IERC20(_lp1Token).transfer(_user, balanceOfWhale / 3);
        IERC20(_lp1Token).transfer(_other, balanceOfWhale / 3);
        vm.stopPrank();

        balanceOfWhale = IERC20(_lp0Token).balanceOf(_whaleLp0Token);
        vm.startPrank(_whaleLp0Token);
        IERC20(_lp0Token).transfer(_user, balanceOfWhale / 3);
        IERC20(_lp0Token).transfer(_other, balanceOfWhale / 3);
        vm.stopPrank();
    }

    ///@notice tests for deposit functio

    function test_DepositAndEpochWhenNotPausedAndCalledByVault() public {
        vm.prank(_user);
        // uint256 stakeBalUSer = IERC20(_stake).balanceOf(_user);
        // emit log_named_uint("stakeBalUSer ", stakeBalUSer);
        IERC20(_stake).transfer(address(parentStrategy), 1e18);
        // vm.expectEmit(false, false, false, true);
        // emit Deposit(1e18, 1e18);
        vm.prank(address(parentVault));
        parentStrategy.deposit();
        uint256 stratStakeBalanceAfter = parentStrategy.balanceOf();
        assertEq(stratStakeBalanceAfter, 1e18);
        vm.stopPrank();

        vm.prank(_user);
        // uint256 _lp1TokenBalUSer = IERC20(_lp1Token).balanceOf(_user);
        // emit log_named_uint("_lp1TokenBalUSer ", _lp1TokenBalUSer);
        IERC20(_lp1Token).transfer(address(asset1Strategy), 1e18);
        vm.prank(address(asset1Vault));
        asset1Strategy.deposit();
        stratStakeBalanceAfter = asset1Strategy.balanceOf();
        assertEq(stratStakeBalanceAfter, 1e18);
        vm.stopPrank();

        vm.prank(_user);
        IERC20(_lp0Token).transfer(address(asset0Strategy), 1e18);
        vm.startPrank(address(asset0Vault));
        asset0Strategy.deposit();
        stratStakeBalanceAfter = asset0Strategy.balanceOf();
        assertEq(stratStakeBalanceAfter, 1e18);
        vm.stopPrank();

        address[] memory strategiesChild = new address[](2);
        strategiesChild[0] = address(asset0Strategy);
        strategiesChild[1] = address(asset1Strategy);
        vm.prank(_user);
        parentStrategy.startEpoch(strategiesChild);

        vm.prank(_user);
        parentStrategy.setPendingRewardsFunctionName("pendingCub");
        // vm.expectEmit(false, false, false, true);

        vm.warp(block.timestamp + 30 * 24 * 60 * 60);
        vm.roll(block.number + 10000);
        _performSwapInBothDirections(1e18);

        parentStrategy.harvest();

        // stratStakeBalanceAfter = parentStrategy._calculatFixedReturnLp();
        vm.prank(_user);
        // emit log_named_uint("_calculatFixedReturnLp", stratStakeBalanceAfter);
        parentStrategy.endEpoch();
        vm.prank(_user);
        // parentStrategy.startEpoch(strategiesChild);
        stratStakeBalanceAfter = parentStrategy.balanceOf();
        emit log_named_uint(
            "stratStakeBalanceAfterEpochEnd",
            stratStakeBalanceAfter
        );

        stratStakeBalanceAfter = asset1Strategy.balanceOf();
        emit log_named_uint("asset1Strategybalance ", stratStakeBalanceAfter);

        stratStakeBalanceAfter = asset0Strategy.balanceOf();
        emit log_named_uint("asset0Strategybalance ", stratStakeBalanceAfter);

        // emit log_named_uint("balanceOfwethParent", balanceOfwethParent);
        // emit log_named_uint("balanceOfcloudParent", balanceOfcloudParent);
    }

    function _performSwapInBothDirections(uint256 swapAmount) internal {
        vm.startPrank(_other);
        IERC20(_lp1Token).approve(_router, type(uint256).max);
        IERC20(_lp0Token).approve(_router, type(uint256).max);
        address[] memory _lp1TokenTowethRoute = new address[](2);
        _lp1TokenTowethRoute[0] = _lp1Token;
        _lp1TokenTowethRoute[1] = _lp0Token;
        address[] memory _lp0TokenTocloudRoute = new address[](2);
        _lp0TokenTocloudRoute[0] = _lp0Token;
        _lp0TokenTocloudRoute[1] = _lp1Token;

        uint[] memory amounts = IPancakeRouter02(_router)
            .swapExactTokensForTokens(
                swapAmount,
                0,
                _lp1TokenTowethRoute,
                address(this),
                block.timestamp
            );

        IPancakeRouter02(_router).swapExactTokensForTokens(
            amounts[1],
            0,
            _lp0TokenTocloudRoute,
            address(this),
            block.timestamp
        );
        vm.stopPrank();
    }

    // function test_DepositWhenPaused() public {
    //     vm.prank(_manager);
    //     strategy.pause();
    //     vm.prank(address(vault));
    //     vm.expectRevert("Pausable: paused");
    //     strategy.deposit();
    // }

    // function test_DepositWhenNotVault() public {
    //     vm.expectRevert("!vault");
    //     strategy.deposit();
    // }

    // ///@notice tests for withdraw function

    // function test_WithdrawWhenCalledByVault() public {
    //     vm.prank(_user);
    //     IERC20(_stake).transfer(address(strategy), 1e18);
    //     vm.prank(address(vault));
    //     strategy.deposit();

    //     uint256 vaultStakeBalanceBefore = IERC20(_stake).balanceOf(address(vault));
    //     assertEq(vaultStakeBalanceBefore, 0);
    //     uint256 stratPoolBalanceBefore = strategy.balanceOfPool();
    //     assertEq(stratPoolBalanceBefore, 1e18);

    //     vm.prank(address(vault));
    //     vm.expectEmit(false, false, false, true);
    //     emit Withdraw(0, 1e18);  //Event emitted it Withdraw(tvl after withdraw)
    //     strategy.withdraw(1e18);

    //     uint256 vaultStakeBalanceAfter = IERC20(_stake).balanceOf(address(vault));
    //     assertEq(vaultStakeBalanceAfter, 1e18);
    //     uint256 stratPoolBalanceAfter = strategy.balanceOfPool();
    //     assertEq(stratPoolBalanceAfter, 0);

    // }

    // function test_WithdrawWhenNotCalledByVault() public {
    //     vm.prank(_user);
    //     IERC20(_stake).transfer(address(strategy), 1e18);
    //     vm.prank(address(vault));
    //     strategy.deposit();

    //     uint256 vaultStakeBalanceBefore = IERC20(_stake).balanceOf(address(vault));
    //     assertEq(vaultStakeBalanceBefore, 0);
    //     uint256 stratPoolBalanceBefore = strategy.balanceOfPool();
    //     assertEq(stratPoolBalanceBefore, 1e18);

    //     vm.expectRevert("!vault");
    //     strategy.withdraw(1e18);

    // }

    // ///@notice tests for harvest functions

    // function test_HarvestWhenNotPaused() public {
    //     vm.prank(_user);
    //     IERC20(_stake).transfer(address(strategy), 1e18);
    //     vm.prank(address(vault));
    //     strategy.deposit();

    //     uint256 stratPoolBalanceBefore = strategy.balanceOfPool();
    //     assertEq(stratPoolBalanceBefore, 1e18);

    //     vm.roll(block.number + 100);

    //     vm.expectEmit(true, false, false, false);
    //     emit StratHarvest(address(this), 0, 0); //We don't try to match the second and third parameter of the event. They're result of Pancake swap contracts, we trust the protocol to be correct.
    //     strategy.harvest();

    //     uint256 stratPoolBalanceAfter = strategy.balanceOfPool();
    //     assertGt(stratPoolBalanceAfter, stratPoolBalanceBefore);
    // }

    // function test_HarvestWhenPaused() public {
    //     vm.prank(_user);
    //     IERC20(_stake).transfer(address(strategy), 1e18);
    //     vm.prank(address(vault));
    //     strategy.deposit();

    //     uint256 stratPoolBalanceBefore = strategy.balanceOfPool();
    //     assertEq(stratPoolBalanceBefore, 1e18);

    //     vm.roll(block.number + 100);

    //     vm.prank(_manager);
    //     strategy.pause();
    //     vm.expectRevert("Pausable: paused");
    //     strategy.harvest();
    // }

    // ///@notice tests for manager harvest functions

    // function test_HarvestWhenCalledByManager() public {
    //     vm.prank(_user);
    //     IERC20(_stake).transfer(address(strategy), 1e18);
    //     vm.prank(address(vault));
    //     strategy.deposit();

    //     uint256 stratPoolBalanceBefore = strategy.balanceOfPool();
    //     assertEq(stratPoolBalanceBefore, 1e18);

    //     vm.roll(block.number + 100);

    //     vm.prank(_manager);
    //     vm.expectEmit(true, false, false, false);
    //     emit StratHarvest(_manager, 0, 0); //We don't try to match the second and third parameter of the event. They're result of Pancake swap contracts, we trust the protocol to be correct.
    //     strategy.managerHarvest();

    //     uint256 stratPoolBalanceAfter = strategy.balanceOfPool();
    //     assertGt(stratPoolBalanceAfter, stratPoolBalanceBefore);
    // }

    // function test_HarvestWhenNotCalledByManager() public {
    //     vm.prank(_user);
    //     IERC20(_stake).transfer(address(strategy), 1e18);
    //     vm.prank(address(vault));
    //     strategy.deposit();

    //     uint256 stratPoolBalanceBefore = strategy.balanceOfPool();
    //     assertEq(stratPoolBalanceBefore, 1e18);

    //     vm.roll(block.number + 100);

    //     vm.prank(_manager);
    //     strategy.pause();
    //     vm.expectRevert("!manager");
    //     strategy.managerHarvest();
    // }

    // function test_BalanceOfStake() public {
    //     uint256 stratStakeBalanceBefore = strategy.balanceOfStake();
    //     assertEq(stratStakeBalanceBefore, 0);

    //     vm.prank(_user);
    //     IERC20(_stake).transfer(address(strategy), 1e18);

    //     uint256 stratStakeBalanceAfter = strategy.balanceOfStake();
    //     assertEq(stratStakeBalanceAfter, 1e18);
    // }

    // function test_BalanceOfPool() public {
    //     uint256 stratPoolBalanceBefore = strategy.balanceOfPool();
    //     assertEq(stratPoolBalanceBefore, 0);

    //     vm.prank(_user);
    //     IERC20(_stake).transfer(address(strategy), 1e18);
    //     vm.prank(address(vault));
    //     strategy.deposit();

    //     uint256 stratPoolBalanceAfter = strategy.balanceOfPool();
    //     assertEq(stratPoolBalanceAfter, 1e18);
    // }

    // function test_BalanceOfStrategy() public {
    //     uint256 stratBalanceBefore = strategy.balanceOf();
    //     assertEq(stratBalanceBefore, 0);

    //     vm.prank(_user);
    //     IERC20(_stake).transfer(address(strategy), 1e18);

    //     vm.prank(_user);
    //     IERC20(_stake).transfer(address(strategy), 1e18);
    //     vm.prank(address(vault));
    //     strategy.deposit();

    //     uint256 stratBalanceAfter = strategy.balanceOf();
    //     assertEq(stratBalanceAfter, 2e18);
    // }

    // function test_SetPendingRewardsFunctionNameCalledByManager() public {
    //     assertEq(strategy.pendingRewardsFunctionName(), "");

    //     vm.prank(_manager);
    //     strategy.setPendingRewardsFunctionName("pendingCake");

    //     assertEq(strategy.pendingRewardsFunctionName(), "pendingCake");
    // }

    // function test_SetPendingRewardsFunctionNameNotCalledByManager() public {
    //     assertEq(strategy.pendingRewardsFunctionName(), "");

    //     vm.expectRevert("!manager");
    //     strategy.setPendingRewardsFunctionName("pendingCake");

    // }

    // function test_RewardsAvailable() public {
    //     assertEq(strategy.pendingRewardsFunctionName(), "");

    //     vm.prank(_manager);
    //     strategy.setPendingRewardsFunctionName("pendingCake");

    //     vm.prank(_user);
    //     IERC20(_stake).transfer(address(strategy), 1e18);
    //     vm.prank(address(vault));
    //     strategy.deposit();

    //     uint256 stratPoolBalanceBefore = strategy.balanceOfPool();
    //     assertEq(stratPoolBalanceBefore, 1e18);

    //     vm.roll(block.number + 100);

    //     assertGt(strategy.rewardsAvailable(), 0);

    // }

    // function testFail_RewardsAvailableBeforeSettingFunctionName() public {
    //     vm.prank(_user);
    //     IERC20(_stake).transfer(address(strategy), 1e18);
    //     vm.prank(address(vault));
    //     strategy.deposit();

    //     uint256 stratPoolBalanceBefore = strategy.balanceOfPool();
    //     assertEq(stratPoolBalanceBefore, 1e18);

    //     vm.roll(block.number + 100);

    //     assertGt(strategy.rewardsAvailable(), 0);
    // }

    // function test_RetireStratWhenCalledByVault() public {

    //     vm.prank(_user);
    //     IERC20(_stake).transfer(address(strategy), 1e18);
    //     vm.prank(address(vault));
    //     strategy.deposit();

    //     vm.prank(_user);
    //     IERC20(_stake).transfer(address(strategy), 1e18);

    //     uint256 stratPoolBalanceBefore = strategy.balanceOfPool();
    //     assertEq(stratPoolBalanceBefore, 1e18);

    //     uint256 stratStakeBalanceBefore = strategy.balanceOfStake();
    //     assertEq(stratStakeBalanceBefore, 1e18);

    //     uint256 vaultStakeBalanceBefore = IERC20(_stake).balanceOf(address(vault));
    //     assertEq(vaultStakeBalanceBefore, 0);

    //     vm.prank(address(vault));
    //     strategy.retireStrat();

    //     uint256 stratPoolBalanceAfterr = strategy.balanceOfPool();
    //     assertEq(stratPoolBalanceAfterr, 0);

    //     uint256 stratStakeBalanceAfter = strategy.balanceOfStake();
    //     assertEq(stratStakeBalanceAfter, 0);

    //     uint256 vaultStakeBalanceAfter = IERC20(_stake).balanceOf(address(vault));
    //     assertEq(vaultStakeBalanceAfter, 2e18);

    // }

    // function test_RetireStratWhenNotCalledByVault() public {

    //     vm.prank(_user);
    //     IERC20(_stake).transfer(address(strategy), 1e18);
    //     vm.prank(address(vault));
    //     strategy.deposit();

    //     vm.prank(_user);
    //     IERC20(_stake).transfer(address(strategy), 1e18);

    //     uint256 stratPoolBalanceBefore = strategy.balanceOfPool();
    //     assertEq(stratPoolBalanceBefore, 1e18);

    //     uint256 stratStakeBalanceBefore = strategy.balanceOfStake();
    //     assertEq(stratStakeBalanceBefore, 1e18);

    //     uint256 vaultStakeBalanceBefore = IERC20(_stake).balanceOf(address(vault));
    //     assertEq(vaultStakeBalanceBefore, 0);

    //     vm.expectRevert("!vault");
    //     strategy.retireStrat();

    // }

    // function test_PanicWhenCalledByManager() public {
    //     vm.prank(_manager);
    //     strategy.panic();

    //     assertEq(strategy.paused(), true);

    //     assertEq(IERC20(_stake).allowance(address(strategy), _chef), 0);
    //     assertEq(IERC20(_cake).allowance(address(strategy), _router), 0);
    //     assertEq(IERC20(_wom).allowance(address(strategy), _router), 0);
    //     assertEq(IERC20(_lp1Token).allowance(address(strategy), _router), 0);
    // }

    // function test_PanicWhenNotCalledByManager() public {
    //     vm.expectRevert("!manager");
    //     strategy.panic();
    // }

    // function test_UnpauseWhenCalledByManager() public {
    //     vm.prank(_manager);
    //     strategy.panic();

    //     assertEq(strategy.paused(), true);

    //     assertEq(IERC20(_stake).allowance(address(strategy), _chef), 0);
    //     assertEq(IERC20(_cake).allowance(address(strategy), _router), 0);
    //     assertEq(IERC20(_wom).allowance(address(strategy), _router), 0);
    //     assertEq(IERC20(_lp1Token).allowance(address(strategy), _router), 0);

    //     vm.prank(_manager);
    //     strategy.unpause();

    //     assertEq(strategy.paused(), false);

    //     assertEq(IERC20(_stake).allowance(address(strategy), _chef), type(uint256).max);
    //     assertEq(IERC20(_cake).allowance(address(strategy), _router), type(uint256).max);
    //     assertEq(IERC20(_wom).allowance(address(strategy), _router), type(uint256).max);
    //     assertEq(IERC20(_lp1Token).allowance(address(strategy), _router), type(uint256).max);
    // }

    // function test_UnpauseWhenNotCalledByManager() public {
    //     vm.expectRevert("!manager");
    //     strategy.unpause();
    // }
}
