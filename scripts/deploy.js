const hre = require('hardhat')

async function main() {
  const [deployer] = await hre.ethers.getSigners()
  console.log('Deploying contracts with the account:', deployer.address)
  console.log('Account balance:', (await deployer.getBalance()).toString())

  const Token = await hre.ethers.getContractFactory('LittleLions')
  const token = await Token.deploy('0xe581f78673C7a98E51348Be72faFAda7D4b84256', 'ipfs://QmZEY653Httf4Z5e5HRvNJMuebhAyKmRG57ycykijSHmjz', 'ipfs://')
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
