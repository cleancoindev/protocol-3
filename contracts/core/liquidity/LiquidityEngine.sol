// Neptune Mutual Protocol (https://neptunemutual.com)
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.0;
// import "../../interfaces/IVault.sol";
import "../Recoverable.sol";
import "../../libraries/StoreKeyUtil.sol";
import "../../libraries/StrategyLibV1.sol";
import "../../interfaces/ILendingStrategy.sol";
import "../../interfaces/ILiquidityEngine.sol";

contract LiquidityEngine is ILiquidityEngine, Recoverable {
  using RegistryLibV1 for IStore;
  using StoreKeyUtil for IStore;
  using StrategyLibV1 for IStore;
  using ValidationLibV1 for IStore;

  constructor(IStore s) Recoverable(s) {} // solhint-disable-line

  function addStrategies(address[] memory strategies) external override nonReentrant {
    s.mustNotBePaused();
    AccessControlLibV1.mustBeLiquidityManager(s);

    s.addStrategiesInternal(strategies);
  }

  function disableStrategy(address strategy) external override nonReentrant {
    // @suppress-address-trust-issue The address strategy can be trusted
    // because this function can only be invoked by a liquidity manager.
    s.mustNotBePaused();
    AccessControlLibV1.mustBeLiquidityManager(s);

    s.disableStrategyInternal(strategy);
    emit StrategyDisabled(strategy);
  }

  function setLendingPeriods(
    bytes32 coverKey,
    uint256 lendingPeriod,
    uint256 withdrawalWindow
  ) external override nonReentrant {
    require(lendingPeriod > 0, "Please specify lending period");
    require(withdrawalWindow > 0, "Please specify withdrawal window");

    s.mustNotBePaused();
    AccessControlLibV1.mustBeLiquidityManager(s);

    s.setLendingPeriodsInternal(coverKey, lendingPeriod, withdrawalWindow);
  }

  function setLendingPeriodsDefault(uint256 lendingPeriod, uint256 withdrawalWindow) external override nonReentrant {
    s.mustNotBePaused();
    AccessControlLibV1.mustBeLiquidityManager(s);

    require(withdrawalWindow > 0, "Please specify withdrawal window");

    s.setLendingPeriodsInternal(0, lendingPeriod, withdrawalWindow);
  }

  function getDisabledStrategies() external view override returns (address[] memory strategies) {
    return s.getDisabledStrategiesInternal();
  }

  function getActiveStrategies() external view override returns (address[] memory strategies) {
    return s.getActiveStrategiesInternal();
  }

  /**
   * @dev Version number of this contract
   */
  function version() external pure override returns (bytes32) {
    return "v0.1";
  }

  /**
   * @dev Name of this contract
   */
  function getName() external pure override returns (bytes32) {
    return ProtoUtilV1.CNAME_LIQUIDITY_ENGINE;
  }
}
