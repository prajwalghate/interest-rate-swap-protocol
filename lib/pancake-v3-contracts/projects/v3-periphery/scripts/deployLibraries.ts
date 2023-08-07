import { ethers, network } from 'hardhat'
import fs from 'fs'

const networkName = network.name
const deployedCoreLibraries: { [name: string]: string } = require(`../../v3-core/deployments/libraries/${networkName}.json`)
console.log(deployedCoreLibraries);

async function main() {
  const [owner] = await ethers.getSigners()
  console.log('owner', owner.address)

  const LiquidityAmounts = await ethers.getContractFactory("LiquidityAmounts", {
    signer: owner,
    libraries: {
        FullMath: deployedCoreLibraries.FullMath,
    },
  });
  let liquidityAmounts = await LiquidityAmounts.deploy()
  await liquidityAmounts.deployed()

  let liquidityAmounts_address = liquidityAmounts.address
  console.log('LiquidityAmounts', liquidityAmounts_address)

  const contracts = {
    LiquidityAmounts: liquidityAmounts_address
  }

  fs.writeFileSync(`./deployments/libraries/${networkName}.json`, JSON.stringify(contracts, null, 2))
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
