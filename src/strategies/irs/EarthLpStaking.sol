pragma solidity ^0.8.0;

import "@openzeppelin/token/ERC20/IERC20.sol";
import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/access/Ownable.sol";
import "@openzeppelin/security/Pausable.sol";
import "@openzeppelin/security/ReentrancyGuard.sol";

import "@pancakeswap-v2-exchange-protocol/interfaces/IPancakeRouter02.sol";
import "@pancakeswap-v2-core/interfaces/IPancakePair.sol";
import "./interfaces/ICommonStrat.sol";
import "./interfaces/IMasterChef.sol";
import "./interfaces/IPancakeFactory.sol";
import "../common/AbstractStrategy.sol";
import "../utils/StringUtils.sol";

struct RiveraLpStakingParams {
    address stake;
    uint256 poolId;
    address chef;
    address[] rewardToLp0Route;
    address[] rewardToLp1Route;
    address baseCurrency;
    address factory;
}

struct ComonStratData {
    uint256 stakedInNative;
    uint256 returnAmountNative;
}

contract EarthLpStaking is AbstractStrategy, ReentrancyGuard {
    using SafeERC20 for IERC20;

    //fixed vaults map
    mapping(address => ComonStratData) public assetStrategyMap;
    address[] public assetStrategies;

    uint256 eachLevAmountInBase;
    bool public epochRunning = false;

    address public baseCurrency;
    address public factory;

    // Tokens used
    address public reward;
    address public stake;
    address public lpToken0;
    address public lpToken1;

    // Third party contracts
    address public chef;
    uint256 public poolId;

    uint256 public lastHarvest;
    string public pendingRewardsFunctionName;

    // Routes
    address[] public rewardToLp0Route;
    address[] public rewardToLp1Route;

    //Events
    event StratHarvest(
        address indexed harvester,
        uint256 stakeHarvested,
        uint256 tvl
    );
    event Deposit(uint256 tvl, uint256 amount);
    event Withdraw(uint256 tvl, uint256 amount);

    ///@dev
    ///@param _riveraLpStakingParams: Has the cake pool specific params
    ///@param _commonAddresses: Has addresses common to all vaults, check Rivera Fee manager for more info
    constructor(
        RiveraLpStakingParams memory _riveraLpStakingParams,
        CommonAddresses memory _commonAddresses
    ) AbstractStrategy(_commonAddresses) {
        stake = _riveraLpStakingParams.stake;
        poolId = _riveraLpStakingParams.poolId;
        chef = _riveraLpStakingParams.chef;
        baseCurrency = _riveraLpStakingParams.baseCurrency;
        factory = _riveraLpStakingParams.factory;

        address[] memory _rewardToLp0Route = _riveraLpStakingParams
            .rewardToLp0Route;
        address[] memory _rewardToLp1Route = _riveraLpStakingParams
            .rewardToLp1Route;

        reward = _rewardToLp0Route[0];

        // setup lp routing
        lpToken0 = IPancakePair(stake).token0();
        require(_rewardToLp0Route[0] == reward, "!rewardToLp0Route");
        require(
            _rewardToLp0Route[_rewardToLp0Route.length - 1] == lpToken0,
            "!rewardToLp0Route"
        );
        rewardToLp0Route = _rewardToLp0Route;

        lpToken1 = IPancakePair(stake).token1();
        require(_rewardToLp1Route[0] == reward, "!rewardToLp1Route");
        require(
            _rewardToLp1Route[_rewardToLp1Route.length - 1] == lpToken1,
            "!rewardToLp1Route"
        );
        rewardToLp1Route = _rewardToLp1Route;

        _giveAllowances();
    }

    // puts the funds to work
    function deposit() public {
        onlyVault();
        // require(!epochRunning);
        if (epochRunning == true) revert();
        _deposit();
    }

    function _deposit() internal whenNotPaused nonReentrant {
        //Entire LP balance of the strategy contract address is deployed to the farm to earn CAKE
        uint256 stakeBal = IERC20(stake).balanceOf(address(this));

        if (stakeBal > 0) {
            IMasterChef(chef).deposit(poolId, stakeBal);
            emit Deposit(balanceOf(), stakeBal);
        }
    }

    function withdraw(uint256 _amount) external nonReentrant {
        onlyVault();
        if (epochRunning == true) revert();
        //Pretty Straight forward almost same as AAVE strategy
        uint256 stakeBal = IERC20(stake).balanceOf(address(this));

        if (stakeBal < _amount) {
            IMasterChef(chef).withdraw(poolId, _amount - stakeBal);
            stakeBal = IERC20(stake).balanceOf(address(this));
        }

        if (stakeBal > _amount) {
            stakeBal = _amount;
        }

        IERC20(stake).safeTransfer(vault, stakeBal);

        emit Withdraw(balanceOf(), stakeBal);
    }

    function beforeDeposit() external virtual {}

    function harvest() external virtual {
        _harvest();
    }

    function managerHarvest() external {
        onlyManager();
        _harvest();
    }

    // compounds earnings and charges performance fee
    function _harvest() internal whenNotPaused {
        IMasterChef(chef).deposit(poolId, 0); //Deopsiting 0 amount will not make any deposit but it will transfer the CAKE rewards owed to the strategy.
        //This essentially harvests the yeild from CAKE.
        uint256 rewardBal = IERC20(reward).balanceOf(address(this)); //reward tokens will be CAKE. Cake balance of this strategy address will be zero before harvest.
        if (rewardBal > 0) {
            addLiquidity();
            uint256 stakeHarvested = balanceOfStake();
            _deposit(); //Deposits the LP tokens from harvest

            lastHarvest = block.timestamp;
            emit StratHarvest(msg.sender, stakeHarvested, balanceOf());
        }
    }

    // Adds liquidity to AMM and gets more LP tokens.
    function addLiquidity() internal {
        //Should convert the CAKE tokens harvested into WOM and BUSD tokens and depost it in the liquidity pool. Get the LP tokens and stake it back to earn more CAKE.
        uint256 rewardHalf = IERC20(reward).balanceOf(address(this)) / 2; //It says IUniswap here which might be inaccurate. If the address is that of pancake swap and method signatures match then the call should be made correctly.
        if (lpToken0 != reward) {
            //Using Uniswap to convert half of the CAKE tokens into Liquidity Pair token 0
            IPancakeRouter02(router).swapExactTokensForTokens(
                rewardHalf,
                0,
                rewardToLp0Route,
                address(this),
                block.timestamp
            );
        }

        if (lpToken1 != reward) {
            //Using Uniswap to convert half of the CAKE tokens into Liquidity Pair token 1
            IPancakeRouter02(router).swapExactTokensForTokens(
                rewardHalf,
                0,
                rewardToLp1Route,
                address(this),
                block.timestamp
            );
        }
        _addLiquidity();
    }

    function _addLiquidity() internal {
        uint256 lp0Bal = IERC20(lpToken0).balanceOf(address(this));
        uint256 lp1Bal = IERC20(lpToken1).balanceOf(address(this));
        IPancakeRouter02(router).addLiquidity( //Liquidity is getting added into to the Liquidity Pair again. This will give the strategy more LP tokens.
            lpToken0,
            lpToken1,
            lp0Bal,
            lp1Bal,
            1,
            1,
            address(this),
            block.timestamp
        );
    }

    function _calculatFixedReturnNative(
        uint256 amount,
        address strategy
    ) internal returns (uint256) {
        return
            amount +
            ((amount * ICommonStrat(strategy).interest()) /
                ICommonStrat(strategy).interestDecimals());
    }

    function arrangeTokens(
        address tokenA,
        address tokenB
    ) public pure returns (address, address) {
        return tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    function tokenAToTokenBConversion(
        address tokenA,
        address tokenB,
        uint256 amount
    ) public view returns (uint256) {
        if (tokenA == tokenB) {
            return amount;
        }
        address lpAddress = IPancakeFactory(factory).getPair(tokenA, tokenB);
        (uint112 _reserve0, uint112 _reserve1, ) = IPancakePair(lpAddress)
            .getReserves();
        (address token0, address token1) = arrangeTokens(tokenA, tokenB);
        return
            token0 == tokenA
                ? ((amount * _reserve1) / _reserve0)
                : ((amount * _reserve0) / _reserve1);
    }

    // function lpTokenToBaseTokenConversion(
    //     address lpToken,
    //     uint256 amount
    // ) public view returns (uint256) {
    //     (uint112 _reserve0, uint112 _reserve1, ) = IPancakePair(lpToken)
    //         .getReserves();
    //     address token0 = IPancakePair(lpToken).token0();
    //     address token1 = IPancakePair(lpToken).token1();
    //     uint256 reserve0InBaseToken = tokenAToTokenBConversion(
    //         token0,
    //         baseCurrency,
    //         _reserve0
    //     );
    //     uint256 reserve1InBaseToken = tokenAToTokenBConversion(
    //         token1,
    //         baseCurrency,
    //         _reserve1
    //     );

    //     uint256 lpTotalSuppy = IPancakePair(lpToken).totalSupply();

    //     return
    //         ((reserve0InBaseToken + reserve1InBaseToken) * amount) /
    //         lpTotalSuppy;
    // }

    function baseTokenToLpTokenConversion(
        address lpToken,
        uint256 amount
    ) public view returns (uint256 lpTokenAmount) {
        (uint112 _reserve0, uint112 _reserve1, ) = IPancakePair(lpToken)
            .getReserves();
        address token0 = IPancakePair(lpToken).token0();
        address token1 = IPancakePair(lpToken).token1();
        uint256 reserve0InBaseToken = tokenAToTokenBConversion(
            token0,
            baseCurrency,
            _reserve0
        );
        uint256 reserve1InBaseToken = tokenAToTokenBConversion(
            token1,
            baseCurrency,
            _reserve1
        );

        uint256 lpTotalSuppy = IPancakePair(lpToken).totalSupply();
        return ((lpTotalSuppy * amount) /
            (reserve0InBaseToken + reserve1InBaseToken));
    }

    function tokenToLpTokenConversion(
        address token,
        uint256 amount
    ) public view returns (uint256) {
        uint256 amountInBase = tokenAToTokenBConversion(
            token,
            baseCurrency,
            amount
        );
        return baseTokenToLpTokenConversion(stake, amountInBase);
    }

    function _calculatFixedReturnLp() public view returns (uint256) {
        uint256 fixedReturnInLp;
        for (uint256 index = 0; index < assetStrategies.length; index++) {
            fixedReturnInLp =
                fixedReturnInLp +
                tokenToLpTokenConversion(
                    ICommonStrat(assetStrategies[index]).asset(),
                    assetStrategyMap[assetStrategies[index]].returnAmountNative
                );
        }
        return fixedReturnInLp;
    }

    // calculate the total underlaying 'stake' held by the strat.
    function balanceOf() public view returns (uint256) {
        return balanceOfStake() + balanceOfPool() - _calculatFixedReturnLp();
    }

    // it calculates how much 'stake' this contract holds.
    function balanceOfStake() public view returns (uint256) {
        return IERC20(stake).balanceOf(address(this));
    }

    // it calculates how much 'stake' the strategy has working in the farm.
    function balanceOfPool() public view returns (uint256) {
        //_amount is the LP token amount the user has provided to stake
        (uint256 _amount, ) = IMasterChef(chef).userInfo(poolId, address(this));
        return _amount;
    }

    function setPendingRewardsFunctionName(
        string calldata _pendingRewardsFunctionName
    ) external {
        onlyManager();
        //Interesting! function name that has to be used itself can be treated as an arguement
        pendingRewardsFunctionName = _pendingRewardsFunctionName;
    }

    // returns rewards unharvested
    function rewardsAvailable() public view returns (uint256) {
        //Returns the rewards available to the strategy contract from the pool
        string memory signature = StringUtils.concat(
            pendingRewardsFunctionName,
            "(uint256,address)"
        );
        bytes memory result = Address.functionStaticCall(
            chef,
            abi.encodeWithSignature(signature, poolId, address(this))
        );
        return abi.decode(result, (uint256));
    }

    // called as part of strat migration. Sends all the available funds back to the vault.
    function retireStrat() external {
        onlyVault();
        IMasterChef(chef).emergencyWithdraw(poolId);

        uint256 stakeBal = IERC20(stake).balanceOf(address(this));
        IERC20(stake).safeTransfer(vault, stakeBal);
    }

    // pauses deposits and withdraws all funds from third party systems.
    function panic() public {
        onlyManager();
        pause();
        IMasterChef(chef).emergencyWithdraw(poolId);
    }

    function pause() public {
        onlyManager();
        _pause();

        _removeAllowances();
    }

    function unpause() external {
        onlyManager();
        _unpause();

        _giveAllowances();

        _deposit();
    }

    function _giveAllowances() internal {
        IERC20(stake).safeApprove(chef, type(uint256).max);
        IERC20(reward).safeApprove(router, type(uint256).max);

        IERC20(lpToken0).safeApprove(router, 0);
        IERC20(lpToken0).safeApprove(router, type(uint256).max);

        IERC20(lpToken1).safeApprove(router, 0);
        IERC20(lpToken1).safeApprove(router, type(uint256).max);
    }

    function _removeAllowances() internal {
        IERC20(stake).safeApprove(chef, 0);
        IERC20(reward).safeApprove(router, 0);
        IERC20(lpToken0).safeApprove(router, 0);
        IERC20(lpToken1).safeApprove(router, 0);
    }

    function rewardToLp0() external view returns (address[] memory) {
        return rewardToLp0Route;
    }

    function rewardToLp1() external view returns (address[] memory) {
        return rewardToLp1Route;
    }
}
