// Neptune Mutual Protocol (https://neptunemutual.com)
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.0;
import "../../Recoverable.sol";
import "../../../interfaces/IFinalization.sol";
import "../../../libraries/GovernanceUtilV1.sol";
import "../../../libraries/ValidationLibV1.sol";
import "../../../libraries/RoutineInvokerLibV1.sol";

/**
 * @title Neptune Mutual Governance: Finalization Contract
 * @dev This contract allows governance agents "finalize"
 * a resolved cover product after the claim period.
 *
 * When a cover product is finalized, it resets back to normal
 * state where tokenholders can again supply liquidity
 * and purchase policies.
 */
abstract contract Finalization is Recoverable, IFinalization {
  using GovernanceUtilV1 for IStore;
  using CoverUtilV1 for IStore;
  using StoreKeyUtil for IStore;
  using ValidationLibV1 for IStore;
  using RoutineInvokerLibV1 for IStore;
  using ProtoUtilV1 for IStore;
  using ValidationLibV1 for bytes32;

  function finalize(bytes32 key, uint256 incidentDate) external override nonReentrant {
    s.mustNotBePaused();
    AccessControlLibV1.mustBeGovernanceAgent(s);
    require(incidentDate > 0, "Please specify incident date");

    s.mustBeClaimingOrDisputed(key);
    s.mustBeValidIncidentDate(key, incidentDate);
    s.mustBeAfterResolutionDeadline(key);
    s.mustBeAfterClaimExpiry(key);

    _finalize(key, incidentDate);
  }

  function _finalize(bytes32 key, uint256 incidentDate) internal {
    // Reset to normal
    // @note: do not pass incident date as we need status by key and incident date for historical significance
    s.setStatusInternal(key, 0, CoverUtilV1.CoverStatus.Normal);

    s.deleteUintByKeys(ProtoUtilV1.NS_GOVERNANCE_REPORTING_INCIDENT_DATE, key);
    s.deleteUintByKeys(ProtoUtilV1.NS_GOVERNANCE_RESOLUTION_TS, key);
    s.deleteUintByKeys(ProtoUtilV1.NS_CLAIM_BEGIN_TS, key);
    s.deleteUintByKeys(ProtoUtilV1.NS_CLAIM_EXPIRY_TS, key);

    s.deleteAddressByKeys(ProtoUtilV1.NS_GOVERNANCE_REPORTING_WITNESS_YES, key);
    s.deleteUintByKeys(ProtoUtilV1.NS_GOVERNANCE_REPORTING_WITNESS_YES, key);
    s.deleteUintByKeys(ProtoUtilV1.NS_RESOLUTION_DEADLINE, key);
    s.deleteBoolByKey(GovernanceUtilV1.getHasDisputeKey(key));

    // @warning: do not uncomment these lines as these vales are required to enable unstaking any time after finalization
    // s.deleteAddressByKeys(ProtoUtilV1.NS_GOVERNANCE_REPORTING_WITNESS_YES, key);
    // s.deleteAddressByKeys(ProtoUtilV1.NS_GOVERNANCE_REPORTING_WITNESS_NO, key);
    // s.deleteAddressByKey(keccak256(abi.encodePacked(ProtoUtilV1.NS_GOVERNANCE_REPORTING_WITNESS_YES, key, incidentDate)));
    // s.deleteAddressByKey(keccak256(abi.encodePacked(ProtoUtilV1.NS_GOVERNANCE_REPORTING_WITNESS_NO, key, incidentDate)));

    s.updateStateAndLiquidity(key);
    emit Finalized(key, msg.sender, incidentDate);
  }
}
