// Neptune Mutual Protocol (https://neptunemutual.com)
// SPDX-License-Identifier: BUSL-1.1
import "./VaultBase.sol";

pragma solidity 0.8.0;

abstract contract VaultLiquidity is VaultBase {
  using ProtoUtilV1 for IStore;
  using RegistryLibV1 for IStore;
  using NTransferUtilV2 for IERC20;

  function transferGovernance(
    bytes32 coverKey,
    address to,
    uint256 amount
  ) external override nonReentrant {
    require(coverKey == key, "Forbidden");

    /******************************************************************************************
      PRE
     ******************************************************************************************/
    address stablecoin = delgate().preTransferGovernance(msg.sender, coverKey, to, amount);

    /******************************************************************************************
      BODY
     ******************************************************************************************/

    IERC20(stablecoin).ensureTransfer(to, amount);

    /******************************************************************************************
      POST
     ******************************************************************************************/
    delgate().postTransferGovernance(msg.sender, coverKey, to, amount);
    emit GovernanceTransfer(to, amount);
  }

  /**
   * @dev Adds liquidity to the specified cover contract
   * @param coverKey Enter the cover key
   * @param amount Enter the amount of liquidity token to supply.
   * @param npmStakeToAdd Enter the amount of NPM token to stake.
   */
  function addLiquidity(
    bytes32 coverKey,
    uint256 amount,
    uint256 npmStakeToAdd
  ) external override nonReentrant {
    // @suppress-acl Marking this as publicly accessible
    require(coverKey == key, "Forbidden");

    /******************************************************************************************
      PRE
     ******************************************************************************************/

    (uint256 podsToMint, uint256 previousNpmStake) = delgate().preAddLiquidity(msg.sender, coverKey, amount, npmStakeToAdd);

    require(podsToMint > 0, "Can't determine PODs");

    /******************************************************************************************
      BODY
     ******************************************************************************************/

    IERC20(sc).ensureTransferFrom(msg.sender, address(this), amount);

    if (npmStakeToAdd > 0) {
      IERC20(s.getNpmTokenAddress()).ensureTransferFrom(msg.sender, address(this), npmStakeToAdd);
    }

    super._mint(msg.sender, podsToMint);

    /******************************************************************************************
      POST
     ******************************************************************************************/

    delgate().postAddLiquidity(msg.sender, coverKey, amount, npmStakeToAdd);

    emit PodsIssued(msg.sender, podsToMint, amount);

    if (previousNpmStake == 0) {
      emit Entered(coverKey, msg.sender);
    }

    emit NPMStaken(msg.sender, npmStakeToAdd);
  }

  /**
   * @dev Removes liquidity from the specified cover contract
   * @param coverKey Enter the cover key
   * @param podsToRedeem Enter the amount of pods to redeem
   * @param npmStakeToRemove Enter the amount of NPM stake to remove.
   */
  function removeLiquidity(
    bytes32 coverKey,
    uint256 podsToRedeem,
    uint256 npmStakeToRemove,
    bool exit
  ) external override nonReentrant {
    // @suppress-acl Marking this as publicly accessible
    require(coverKey == key, "Forbidden");

    /******************************************************************************************
      PRE
     ******************************************************************************************/
    (address stablecoin, uint256 stablecoinToRelease) = delgate().preRemoveLiquidity(msg.sender, coverKey, podsToRedeem, npmStakeToRemove, exit);

    /******************************************************************************************
      BODY
     ******************************************************************************************/
    IERC20(address(this)).ensureTransferFrom(msg.sender, address(this), podsToRedeem);
    IERC20(stablecoin).ensureTransfer(msg.sender, stablecoinToRelease);

    // Unstake NPM tokens
    if (npmStakeToRemove > 0) {
      IERC20(s.getNpmTokenAddress()).ensureTransfer(msg.sender, npmStakeToRemove);
    }

    /******************************************************************************************
      POST
     ******************************************************************************************/
    delgate().postRemoveLiquidity(msg.sender, coverKey, podsToRedeem, npmStakeToRemove, exit);

    emit PodsRedeemed(msg.sender, podsToRedeem, stablecoinToRelease);

    if (exit) {
      emit Exited(coverKey, msg.sender);
    }

    if (npmStakeToRemove > 0) {
      emit NPMUnstaken(msg.sender, npmStakeToRemove);
    }
  }

  /**
   * @dev Calculates the amount of PODS to mint for the given amount of liquidity to transfer
   */
  function calculatePods(uint256 forStablecoinUnits) external view override returns (uint256) {
    return delgate().calculatePodsImplementation(key, forStablecoinUnits);
  }

  /**
   * @dev Calculates the amount of stablecoins to withdraw for the given amount of PODs to redeem
   */
  function calculateLiquidity(uint256 podsToBurn) external view override returns (uint256) {
    return delgate().calculateLiquidityImplementation(key, podsToBurn);
  }

  /**
   * @dev Returns the stablecoin balance of this vault
   * This also includes amounts lent out in lending strategies
   */
  function getStablecoinBalanceOf() external view override returns (uint256) {
    return delgate().getStablecoinBalanceOfImplementation(key);
  }

  function accrueInterest() external override nonReentrant {
    delgate().accrueInterestImplementation(msg.sender, key);
    emit InterestAccrued(key);
  }
}
