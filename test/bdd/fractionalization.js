/* eslint-disable no-unused-expressions */
const { network } = require('hardhat')
const BigNumber = require('bignumber.js')
const { helper, key, ipfs, sample } = require('../../util')
const composer = require('../../util/composer')

require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bignumber')(BigNumber))
  .should()

const DAYS = 86400
const formatEther = (x) => (parseInt(x.toString()) / 1e18).toLocaleString()

const coverKey = key.toBytes32('Compound Finance Cover')

/**
 * @type {Contracts}
 */
let contracts = {}

describe('Fractionalization of Reserves', () => {
  beforeEach(async () => {
    contracts = await composer.initializer.initialize(true)

    const info = await ipfs.write(sample.info)

    // console.info(`https://ipfs.infura.io/ipfs/${ipfs.toIPFShash(info)}`)

    const stakeWithFee = helper.ether(10_000)
    const initialLiquidity = helper.ether(4_000_000)
    const minReportingStake = helper.ether(250)
    const reportingPeriod = 7 * DAYS
    const cooldownPeriod = 1 * DAYS
    const claimPeriod = 7 * DAYS
    const floor = helper.percentage(7)
    const ceiling = helper.percentage(45)

    await contracts.npm.approve(contracts.stakingContract.address, stakeWithFee)

    const requiresWhitelist = false
    const values = [stakeWithFee, '0', minReportingStake, reportingPeriod, cooldownPeriod, claimPeriod, floor, ceiling]
    await contracts.cover.addCover(coverKey, info, contracts.reassuranceToken.address, requiresWhitelist, values)
    await contracts.cover.deployVault(coverKey)

    const vault = await composer.vault.getVault(contracts, coverKey)

    await contracts.dai.approve(vault.address, initialLiquidity)
    await contracts.npm.approve(vault.address, minReportingStake)
    await vault.addLiquidity(coverKey, initialLiquidity, minReportingStake)
  })

  it('does not allow fractional reserves', async () => {
    let totalPurchased = 0
    const amount = 2_000_000

    for (let i = 0; i < 2; i++) {
      const args = [coverKey, 2, helper.ether(amount)]
      const info = (await contracts.policy.getCoverFeeInfo(...args))
      const fee = info.fee
      const available = info.totalAvailableLiquidity

      console.info('[#%s] Fee: %s. Total purchased %s. Available Now: %s', i + 1, formatEther(fee), totalPurchased.toLocaleString(), formatEther(available))

      await contracts.dai.approve(contracts.policy.address, fee)
      await contracts.policy.purchaseCover(...args)

      totalPurchased += amount
    }

    await contracts.policy.getCoverFeeInfo(coverKey, 2, helper.ether(200_000)).should.be.rejectedWith('Insufficient fund')
  })

  it('allows reuse of liquidity as policies expire', async () => {
    let totalPurchased = 0
    const amount = 250_000

    // Never ending
    for (let i = 0; i < 20; i++) {
      const args = [coverKey, 2, helper.ether(amount)]
      const info = (await contracts.policy.getCoverFeeInfo(...args))
      const fee = info.fee
      const available = info.totalAvailableLiquidity

      console.info('[#%s] Fee: %s. Total purchased %s. Available Now: %s', i + 1, formatEther(fee), totalPurchased.toLocaleString(), formatEther(available))

      await contracts.dai.approve(contracts.policy.address, fee)
      await contracts.policy.purchaseCover(...args)

      totalPurchased += amount
      await network.provider.send('evm_increaseTime', [7 * DAYS])
    }
  })

  it('commitments expire over time', async () => {
    const amount = 250_000

    for (let i = 0; i < 8; i++) {
      const args = [coverKey, 1, helper.ether(amount)]
      const info = (await contracts.policy.getCoverFeeInfo(...args))
      const fee = info.fee

      if (i < 4) {
        await contracts.dai.approve(contracts.policy.address, fee)
        await contracts.policy.purchaseCover(...args)
      }

      await network.provider.send('evm_increaseTime', [7 * DAYS])
      // Dummy transaction
      await contracts.npm.approve(contracts.governance.address, helper.ether(1000))
    }

    const commitment = await contracts.policy.getCommitment(coverKey)
    commitment.should.equal('0')
  })
})
