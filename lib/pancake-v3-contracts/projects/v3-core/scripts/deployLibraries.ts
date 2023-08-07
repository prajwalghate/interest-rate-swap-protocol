import { tryVerify } from '@pancakeswap/common/verify'
import { ContractFactory } from 'ethers'
import { ethers, network } from 'hardhat'
import fs from 'fs'

type ContractJson = { abi: any; bytecode: string }
const artifacts: { [name: string]: ContractJson } = {
  // eslint-disable-next-line global-require
  TickMath: require('../artifacts/contracts/libraries/TickMath.sol/TickMath.json'),
  // eslint-disable-next-line global-require
  LowGasSafeMath: require('../artifacts/contracts/libraries/LowGasSafeMath.sol/LowGasSafeMath.json'),
  // eslint-disable-next-line global-require
  UnsafeMath: require('../artifacts/contracts/libraries/UnsafeMath.sol/UnsafeMath.json'),
  // eslint-disable-next-line global-require
  FixedPoint96: require('../artifacts/contracts/libraries/FixedPoint96.sol/FixedPoint96.json'),
  // eslint-disable-next-line global-require
  SqrtPriceMath: require('../artifacts/contracts/libraries/SqrtPriceMath.sol/SqrtPriceMath.json'),
  // eslint-disable-next-line global-require
  LiquidityMath: require('../artifacts/contracts/libraries/LiquidityMath.sol/LiquidityMath.json'),
  // eslint-disable-next-line global-require
  SafeCast: require('../artifacts/contracts/libraries/SafeCast.sol/SafeCast.json'),
  // eslint-disable-next-line global-require
  FullMath: require('../artifacts/contracts/libraries/FullMath.sol/FullMath.json'),
}

async function main() {
  const [owner] = await ethers.getSigners()
  const networkName = network.name
  console.log('owner', owner.address)

  const TickMath = new ContractFactory(
    artifacts.TickMath.abi,
    artifacts.TickMath.bytecode,
    owner
  )
  let tickMath = await TickMath.deploy()
  await tickMath.deployed()

  let tickMath_address = tickMath.address
  console.log('TickMath', tickMath_address)

  const SafeCast = new ContractFactory(
    artifacts.SafeCast.abi,
    artifacts.SafeCast.bytecode,
    owner
  )
  let safeCast = await SafeCast.deploy()
  await safeCast.deployed()

  let safeCast_address = safeCast.address
  console.log('SafeCast', safeCast_address)

  const FullMath = new ContractFactory(
    artifacts.FullMath.abi,
    artifacts.FullMath.bytecode,
    owner
  )
  let fullMath = await FullMath.deploy()
  await fullMath.deployed()

  let fullMath_address = fullMath.address
  console.log('FullMath', fullMath_address)

  const LowGasSafeMath = new ContractFactory(
    artifacts.LowGasSafeMath.abi,
    artifacts.LowGasSafeMath.bytecode,
    owner
  )
  let lowGasSafeMath = await LowGasSafeMath.deploy()
  await lowGasSafeMath.deployed()

  let lowGasSafeMath_address = lowGasSafeMath.address
  console.log('LowGasSafeMath', lowGasSafeMath_address)

  const UnsafeMath = new ContractFactory(
    artifacts.UnsafeMath.abi,
    artifacts.UnsafeMath.bytecode,
    owner
  )
  let unsafeMath = await UnsafeMath.deploy()
  await unsafeMath.deployed()

  let unsafeMath_address = unsafeMath.address
  console.log('UnsafeMath', unsafeMath_address)

  const FixedPoint96 = new ContractFactory(
    artifacts.FixedPoint96.abi,
    artifacts.FixedPoint96.bytecode,
    owner
  )
  let fixedPoint96 = await FixedPoint96.deploy()
  await fixedPoint96.deployed()

  let fixedPoint96_address = fixedPoint96.address
  console.log('FixedPoint96', fixedPoint96_address)

  const SqrtPriceMath = await ethers.getContractFactory("SqrtPriceMath", {
    signer: owner,
    libraries: {
        SafeCast: safeCast_address,
        FullMath: fullMath_address,
    },
  });

  let sqrtPriceMath = await SqrtPriceMath.deploy()
  await sqrtPriceMath.deployed()

  let sqrtPriceMath_address = sqrtPriceMath.address
  console.log('SqrtPriceMath', sqrtPriceMath_address)

  const LiquidityMath = new ContractFactory(
    artifacts.LiquidityMath.abi,
    artifacts.LiquidityMath.bytecode,
    owner
  )
  let liquidityMath = await LiquidityMath.deploy()
  await liquidityMath.deployed()

  let liquidityMath_address = liquidityMath.address
  console.log('LiquidityMath', liquidityMath_address)


  const contracts = {
    TickMath: tickMath_address,
    SqrtPriceMath: sqrtPriceMath_address,
    LiquidityMath: liquidityMath_address,
    SafeCast: safeCast_address,
    FullMath: fullMath_address,
    LowGasSafeMath: lowGasSafeMath_address,
    UnsafeMath: unsafeMath_address,
    FixedPoint96: fixedPoint96_address
  }

  fs.writeFileSync(`./deployments/libraries/${networkName}.json`, JSON.stringify(contracts, null, 2))
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
