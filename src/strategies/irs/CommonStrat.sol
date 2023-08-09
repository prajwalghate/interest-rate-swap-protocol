pragma solidity ^0.8.0;

import "@openzeppelin/token/ERC20/IERC20.sol";
import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/security/ReentrancyGuard.sol";
import "@openzeppelin/access/Ownable.sol";
import "@openzeppelin/security/Pausable.sol";
import "../common/interfaces/IStrategy.sol";

contract CommonStrat is ReentrancyGuard, Ownable, Pausable {
    using SafeERC20 for IERC20;

    address public manager;
    address public asset;
    address public vault;
    address public parentStrategy;
    uint256 public interestDecimals;
    uint256 public interest;

    //Events
    event Deposit(uint256 tvl, uint256 amount);
    event Withdraw(uint256 tvl, uint256 amount);
    event SetManager(address manager);
    event SetVault(address vault);

    constructor(
        address _vault,
        address _parentStrategy,
        uint256 _interest,
        uint256 _interestDecimals
    ) {
        vault = _vault;
        parentStrategy = _parentStrategy;
        interest = _interest;
        interestDecimals = _interestDecimals;
        (bool success, bytes memory data) = vault.call(
            abi.encodeWithSelector(bytes4(keccak256(bytes("asset()"))))
        );
        require(success, "AF");
        asset = abi.decode(data, (address));
        _giveAllowances();
    }

    // puts the funds to work
    function deposit() public {
        onlyVault();
        _deposit();
    }

    function _deposit() internal whenNotPaused nonReentrant {
        bool epoch = IStrategy(parentStrategy).epochRunning();
        if (epoch == true) revert();
    }

    function withdraw(uint256 _amount) external nonReentrant {
        onlyVault();
        bool epoch = IStrategy(parentStrategy).epochRunning();
        if (epoch == true) revert();
        IERC20(asset).safeTransfer(vault, _amount);
        emit Withdraw(balanceOf(), _amount);
    }

    function beforeDeposit() external virtual {}

    // calculate the total underlaying 'stake' held by the strat.
    function balanceOf() public view returns (uint256) {
        return
            balanceOfAsset() +
            IStrategy(parentStrategy)
                .assetStrategyMap(address(this))
                .returnAmountNative;
    }

    // it calculates how much 'stake' this contract holds.
    function balanceOfAsset() public view returns (uint256) {
        return IERC20(asset).balanceOf(address(this));
    }

    // called as part of strat migration. Sends all the available funds back to the vault.
    function retireStrat() external {
        onlyVault();

        uint256 assetBal = IERC20(asset).balanceOf(address(this));
        IERC20(asset).safeTransfer(vault, assetBal);
    }

    // pauses deposits and withdraws all funds from third party systems.
    function panic() public {
        onlyManager();
        pause();
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
        IERC20(asset).safeApprove(parentStrategy, type(uint256).max);
    }

    function _removeAllowances() internal {
        IERC20(asset).safeApprove(parentStrategy, 0);
    }

    function onlyVault() public view {
        require(msg.sender == vault, "!vault");
    }

    function onlyManager() public view {
        require(msg.sender == manager, "!manager");
    }

    // set new vault (only for strategy upgrades)
    function setVault(address _vault) external {
        onlyManager();
        vault = _vault;
        emit SetVault(_vault);
    }

    // set new manager to manage strat
    function setManager(address _manager) external {
        onlyManager();
        manager = _manager;
        emit SetManager(_manager);
    }
}
