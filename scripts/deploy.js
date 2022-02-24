const hre = require('hardhat')

async function main() {
  const [deployer] = await hre.ethers.getSigners()
  console.log('Deploying contracts with the account:', deployer.address)
  console.log('Account balance:', (await deployer.getBalance()).toString())

  const Token = await hre.ethers.getContractFactory('CryptoBabyLions')
  const token = await Token.deploy(
    'ipfs://QmY74JZrwu9r1B5RChzpk3E4TGjPrg3io2tWvbvJmJ3kQx',
    'ipfs://QmXAZvyHxDV9GY3gehtX5D9TAk4iFjRn3GHEiuxB6s28An/',
    'https://cryptobabylions.com/assets/metadata/',
  )
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
