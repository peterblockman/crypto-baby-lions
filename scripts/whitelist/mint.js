const hre = require('hardhat')
const whitelist = require('./whitelist.json')

async function main() {
  const [deployer] = await hre.ethers.getSigners()
  console.log('Interacting contract with the account:', deployer.address)
  console.log('Account balance:', (await deployer.getBalance()).toString())

  const Token = await hre.ethers.getContractFactory('CryptoBabyLions')
  const token = await Token.attach(whitelist.contract)

  const mintTx = await token.whitelistMint(whitelist.quantity, whitelist.id, whitelist.merkleProofs[deployer.address], {
    gasLimit: 3000000,
    value: new hre.BigNumber(whitelist.price).mul(whitelist.quantity),
  })
  console.log('Mint tx hash:', mintTx.hash)
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
