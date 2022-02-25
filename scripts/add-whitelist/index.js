const fs = require('fs')
const hre = require('hardhat')
const keccak256 = require('keccak256')
const { MerkleTree } = require('merkletreejs')
const whitelist = require('./whitelist.json')

async function main() {
  const [deployer] = await hre.ethers.getSigners()
  console.log('Interacting contract with the account:', deployer.address)
  console.log('Account balance:', (await deployer.getBalance()).toString())

  const Token = await hre.ethers.getContractFactory('CryptoBabyLions')
  const token = await Token.attach(whitelist.contract)

  const leafNodes = whitelist.addresses.map((address) => keccak256(address))
  const merkleTree = new MerkleTree(leafNodes, keccak256, { sortPairs: true })

  const merkleRoot = merkleTree.getRoot()
  const merkleProofs = {}
  for (let i = 0; i < whitelist.addresses.length; i++) {
    merkleProofs[whitelist.addresses[i]] = merkleTree.getHexProof(keccak256(whitelist.addresses[i]))
  }

  fs.writeFileSync(
    __dirname + '/whitelist.json',
    JSON.stringify({ ...whitelist, merkleRoot: merkleRoot.toString('hex'), merkleProofs }, null, 2)
  )

  const addWhitelistTx = await token.addWhitelist(merkleRoot, whitelist.quantity, whitelist.price)
  console.log(addWhitelistTx.hash)
  addWhitelistTx.wait(1)

  const mintTx = await token.whitelistMint(2, 1, merkleTree.getHexProof(keccak256(deployer.address)), {gasLimit: 1000000,})
  console.log(mintTx.hash)
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
