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
  
  const merkleProofs = {}
  const id = await token.whitelistPlansCounter();

  const leafNodes = whitelist.addresses.map((address) => keccak256(address))
  const merkleTree = new MerkleTree(leafNodes, keccak256, { sortPairs: true })

  const merkleRoot = merkleTree.getRoot()
  for (let i = 0; i < whitelist.addresses.length; i++) {
    merkleProofs[whitelist.addresses[i]] = merkleTree.getHexProof(keccak256(whitelist.addresses[i]))
  }


  const addWhitelistTx = await token.addWhitelist(merkleRoot, whitelist.quantity, whitelist.price);
  console.log('Add whitelist tx hash:', addWhitelistTx.hash);

  fs.writeFileSync(
    __dirname + '/whitelist.json',
    JSON.stringify({ ...whitelist, id, merkleRoot: merkleRoot.toString('hex'), merkleProofs }, null, 2)
  )
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
