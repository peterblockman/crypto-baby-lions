// We import Chai to use its asserting functions here.
const { expect } = require('chai')

// `describe` is a Mocha function that allows you to organize your tests. It's
// not actually needed, but having your tests organized makes debugging them
// easier. All Mocha functions are available in the global scope.

// `describe` receives the name of a section of your test suite, and a callback.
// The callback must define the tests of that section. This callback can't be
// an async function.
describe('Little lions contract', function () {
  // Mocha has four functions that let you hook into the the test runner's
  // lifecyle. These are: `before`, `beforeEach`, `after`, `afterEach`.

  // They're very useful to setup the environment for tests, and to clean it
  // up after they run.

  // A common pattern is to declare some variables, and assign them in the
  // `before` and `beforeEach` callbacks.

  let hardhatInstance
  let owner
  let addr1
  let addr2
  let addrs

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    instance = await ethers.getContractFactory('LittleLions')
    ;[owner, addr1, addr2, ...addrs] = await ethers.getSigners()

    // To deploy our contract, we just have to call instance.deploy() and await
    // for it to be deployed(), which happens onces its transaction has been
    // mined.
    hardhatInstance = await instance.deploy('', '')
  })

  // You can nest describe calls to create subsections.
  describe('Deployment', function () {
    // `it` is another Mocha function. This is the one you use to define your
    // tests. It receives the test name, and a callback function.

    // If the callback function is async, Mocha will `await` it.
    it('Should set the right owner', async function () {
      // Expect receives a value, and wraps it in an Assertion object. These
      // objects have a lot of utility methods to assert values.

      // This test expects the owner variable stored in the contract to be equal
      // to our Signer's owner.
      expect(await hardhatInstance.owner()).to.equal(owner.address)
    })
  })

  describe('Whitelist Mint', function () {
    it('Should mint nfts by whitelisted wallets', async function () {
      await hardhatInstance.addWhitelist([addr1.address], 5)
      await hardhatInstance.connect(addr1).mint(5)

      const addr1Balance = await hardhatInstance.balanceOf(addr1.address)
      expect(addr1Balance.toNumber()).to.equal(5)
    })

    it('Should mint nfts by public', async function () {
      await hardhatInstance.setStartBlock(0)
      await hardhatInstance.connect(addr1).mint(3, { value: ethers.utils.parseEther('0.15') })

      const addr1Balance = await hardhatInstance.balanceOf(addr1.address)
      expect(addr1Balance.toNumber()).to.equal(3)
    })

    it('Should fails for sending not enough eth', async function () {
      await hardhatInstance.setStartBlock(0)
      await expect(hardhatInstance.mint(3)).to.be.throw
    })
  })
})
