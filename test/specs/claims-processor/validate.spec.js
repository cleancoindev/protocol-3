const moment = require('moment')
const BigNumber = require('bignumber.js')
const { deployer, key } = require('../../../util')
const { deployDependencies } = require('./deps')
const attacher = require('../../../util/attach')

const cache = null

require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bignumber')(BigNumber))
  .should()

describe('Claims Processor: `validate` function', () => {
  let libraries, store, cxToken, processor

  beforeEach(async () => {
    libraries = await deployDependencies()

    const storeLib = await deployer.deploy(cache, 'MockProcessorStoreLib')

    store = await deployer.deployWithLibraries(cache, 'MockProcessorStore', { MockProcessorStoreLib: storeLib.address })
    cxToken = await deployer.deploy(cache, 'MockCxToken')
    processor = await deployer.deployWithLibraries(cache, 'Processor', libraries.dependencies, store.address)
  })

  it('must succeed if all conditions are met', async () => {
    const coverKey = key.toBytes32('test')
    const incidentDate = '1234'

    await store.initialize(coverKey, cxToken.address)
    await cxToken.approve(processor.address, '1')

    await processor.validate(cxToken.address, coverKey, incidentDate)
  })

  it('must reject if the protocol is paused', async () => {
    const coverKey = key.toBytes32('test')
    const incidentDate = '1234'

    const [protocolAddress] = await store.callStatic.initialize(coverKey, cxToken.address)
    await store.initialize(coverKey, cxToken.address)

    const protocol = await attacher.protocol.attach(protocolAddress, libraries.all)
    await protocol.setPaused(true)

    await cxToken.approve(processor.address, '1')
    await processor.validate(cxToken.address, coverKey, incidentDate).should.be.rejectedWith('Protocol is paused')
    await protocol.setPaused(false)
  })

  it('must reject if the cxToken is not associated with the given cover key', async () => {
    const coverKey = key.toBytes32('test')
    const incidentDate = '1234'

    await store.initialize(coverKey, cxToken.address)
    await store.disassociateCxToken(cxToken.address)

    await cxToken.approve(processor.address, '1')
    await processor.validate(cxToken.address, coverKey, incidentDate).should.be.rejectedWith('Unknown cxToken')
  })

  it('must reject if the cxToken key does not match with the given cover key', async () => {
    const coverKey = key.toBytes32('invalid-key')
    const incidentDate = '1234'

    await store.initialize(coverKey, cxToken.address)

    await cxToken.approve(processor.address, '1')
    await processor.validate(cxToken.address, coverKey, incidentDate).should.be.rejectedWith('Invalid cxToken')
  })

  it('must reject if the cxToken has already expired', async () => {
    const coverKey = key.toBytes32('test')
    const incidentDate = moment('2055-01-01') // very far into the future

    await store.initialize(coverKey, cxToken.address)

    await cxToken.approve(processor.address, '1')
    await processor.validate(cxToken.address, coverKey, incidentDate.unix()).should.be.rejectedWith('Invalid or expired cxToken')
  })

  it('must reject if the cover is not resolved, i.e. claimable', async () => {
    const coverKey = key.toBytes32('test')
    const incidentDate = '1234'

    await store.initialize(coverKey, cxToken.address)
    await store.setCoverStatus(coverKey, 1)

    await cxToken.approve(processor.address, '1')
    await processor.validate(cxToken.address, coverKey, incidentDate).should.be.rejectedWith('Not claimable')
  })

  it('must reject if incident date is invalid', async () => {
    const coverKey = key.toBytes32('test')
    const incidentDate = '12345'

    await store.initialize(coverKey, cxToken.address)

    await cxToken.approve(processor.address, '1')
    await processor.validate(cxToken.address, coverKey, incidentDate).should.be.rejectedWith('Invalid incident date')
  })

  it('must reject if there is no claim begin date set', async () => {
    const coverKey = key.toBytes32('test')
    const incidentDate = '1234'

    await store.initialize(coverKey, cxToken.address)

    await store.setClaimBeginTimestamp(coverKey, '0')
    await store.setClaimExpiryTimestamp(coverKey, moment('2030-01-02').unix())

    await cxToken.approve(processor.address, '1')
    await processor.validate(cxToken.address, coverKey, incidentDate).should.be.rejectedWith('Invalid claim begin date')
  })

  it('must reject if claim expiry date is greater than claim begin date', async () => {
    const coverKey = key.toBytes32('test')
    const incidentDate = '1234'

    await store.initialize(coverKey, cxToken.address)

    await store.setClaimBeginTimestamp(coverKey, moment('2030-02-01').unix())
    await store.setClaimExpiryTimestamp(coverKey, moment('2030-01-01').unix())

    await cxToken.approve(processor.address, '1')
    await processor.validate(cxToken.address, coverKey, incidentDate).should.be.rejectedWith('Invalid claim period')
  })

  it('must reject if claim period has not begun', async () => {
    const coverKey = key.toBytes32('test')
    const incidentDate = '1234'

    await store.initialize(coverKey, cxToken.address)

    await store.setClaimBeginTimestamp(coverKey, moment('2030-01-01').unix())
    await store.setClaimExpiryTimestamp(coverKey, moment('2030-01-02').unix())

    await cxToken.approve(processor.address, '1')
    await processor.validate(cxToken.address, coverKey, incidentDate).should.be.rejectedWith('Claim period hasn\'t begun')
  })

  it('must reject if claim period is over or expired', async () => {
    const coverKey = key.toBytes32('test')
    const incidentDate = '1234'

    await store.initialize(coverKey, cxToken.address)

    await store.setClaimBeginTimestamp(coverKey, moment('2010-01-01').unix())
    await store.setClaimExpiryTimestamp(coverKey, moment('2010-01-02').unix())

    await cxToken.approve(processor.address, '1')
    await processor.validate(cxToken.address, coverKey, incidentDate).should.be.rejectedWith('Claim period has expired')
  })
})
