const hre = require('hardhat')

async function main() {
  const [deployer] = await hre.ethers.getSigners()
  console.log('Deploying contracts with the account:', deployer.address)
  console.log('Account balance:', (await deployer.getBalance()).toString())

  const Token = await hre.ethers.getContractFactory('LittleLions')
  const token = await Token.deploy('ipfs://', 'ipfs://')
  const s = await token.deployed()
  console.log('Token deployed to:', token.address)
  console.log('Gas Used:', s.deployTransaction.gasLimit.toString())

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms * 1000))
}
