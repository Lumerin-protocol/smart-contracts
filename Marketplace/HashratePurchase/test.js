let { expect } = require("chai");
let { ethers } = require("hardhat");
let sleep = require("sleep");

describe("ContractPurchase", function () {
  this.timeout(600 * 1000);
  let purchase_price = 1000;
  let contract_length = 10;
  let owner, buyer, seller, validator;
  //let ownerBalance, buyerBalance, sellerBalance, validatorBalance;
  let ownerBalance;
  let Implementation;
  let cloneFactory;
  let lumerin;

  before(async function () {
    [owner, buyer, seller, validator] = await ethers.getSigners();
    ownerBalance = await owner.getBalance();
    buyerBalance = await buyer.getBalance();
    sellerBalance = await seller.getBalance();
    validatorBalance = await validator.getBalance();
    Implementation = await ethers.getContractFactory("Implementation");

    let Lumerin = await ethers.getContractFactory("Lumerin");
    lumerin = await Lumerin.deploy();
    await lumerin.deployed();

    let CloneFactory = await ethers.getContractFactory("CloneFactory");
    //deploying with the validator as the address collecting titans lumerin
    cloneFactory = await CloneFactory.deploy(
      lumerin.address,
      lumerin.address,
      validator.address
    );
    await cloneFactory.deployed();
    ownerBalance = await lumerin.balanceOf(owner.address);
    expect(await lumerin.totalSupply()).to.equal(ownerBalance);
  });

  beforeEach(async function () {
    let lumerintx = await lumerin.transfer(buyer.address, 10000);
    await lumerintx.wait();
    let contractsBefore = await cloneFactory.getContractList();
    let contractCreate = await cloneFactory
      .connect(seller)
      .setCreateNewRentalContract(
        purchase_price,
        10,
        10,
        contract_length,
        validator.address,
        "123"
      );
    await contractCreate.wait();
    let contractsAfter = await cloneFactory.getContractList();

    expect(contractsAfter.length).to.equal(contractsBefore.length + 1);

    //buyer increases allowance of clone factory prior to contract purchase
    let allowanceIncrease = await lumerin
      .connect(buyer)
      .increaseAllowance(cloneFactory.address, 10000);
    await allowanceIncrease.wait();
  });

  it("standard purchase and withdrawl", async function () {
    //buyer calls purchase function on clone factory

    let contracts = await cloneFactory.getContractList();
    let contractAddress = contracts[contracts.length - 1];
    let purchaseContract = await cloneFactory
      .connect(buyer)
      .setPurchaseRentalContract(contractAddress, "123");
    await purchaseContract.wait();
    //seller closes out the contract and collects the lumerin tokens
    let contract1 = await Implementation.attach(contractAddress);
    let sellerBeforeCloseout = await lumerin.balanceOf(seller.address);
    sleep.sleep(contract_length);
    let closeOut = await contract1.connect(seller).setContractCloseOut(3);
    await closeOut.wait();
    let sellerAfterCloseout = await lumerin.balanceOf(seller.address);
    expect(
      Number(sellerAfterCloseout) - Number(sellerBeforeCloseout),
      `expected the seller to have ${
        sellerBeforeCloseout + purchase_price
      } but seller has ${sellerAfterCloseout}`
    ).to.equal(purchase_price);
  });

  it("purchase twice and withdraw tokens each time", async function () {
    let contracts = await cloneFactory.getContractList();
    let contractAddress = contracts[contracts.length - 1];
    let sellerBeforePurchase = await lumerin.balanceOf(seller.address);
    let buyerBeforePurchase = await lumerin.balanceOf(buyer.address);
    let contract1 = await Implementation.attach(contractAddress);
    let purchaseContract = await cloneFactory
      .connect(buyer)
      .setPurchaseRentalContract(contractAddress, "123");
    await purchaseContract.wait();
    let contractBalance = await lumerin.balanceOf(contractAddress);
    expect(Number(contractBalance)).to.be.equal(purchase_price);
    let buyerAfterPurchase = await lumerin.balanceOf(buyer.address);
    expect(
      Number(buyerAfterPurchase) - Number(buyerBeforePurchase)
    ).to.be.equal(-purchase_price);
    sleep.sleep(contract_length);
    let closeOut = await contract1.connect(seller).setContractCloseOut(3);
    await closeOut.wait();
    let sellerAfterCloseout = await lumerin.balanceOf(seller.address);
    expect(
      Number(sellerAfterCloseout) - Number(sellerBeforePurchase)
    ).to.be.equal(purchase_price);
    sellerBeforePurchase = await lumerin.balanceOf(seller.address);
    purchaseContract = await cloneFactory
      .connect(buyer)
      .setPurchaseRentalContract(contractAddress, "123");
    await purchaseContract.wait();
    contractBalance = await lumerin.balanceOf(contractAddress);
    expect(Number(contractBalance)).to.be.equal(purchase_price);
    buyerAfterPurchase = await lumerin.balanceOf(buyer.address);
    expect(
      Number(buyerAfterPurchase) - Number(buyerBeforePurchase)
    ).to.be.equal(-purchase_price * 2);
    sleep.sleep(contract_length);
    let secondCloseOut = await contract1.connect(seller).setContractCloseOut(3);
    await secondCloseOut.wait();
    sellerAfterCloseout = await lumerin.balanceOf(seller.address);
    expect(
      Number(sellerAfterCloseout) - Number(sellerBeforePurchase)
    ).to.be.equal(purchase_price);
    await secondCloseOut.wait();
  });

  it("standard purchase and closeout without withdrawl", async function () {
    //buyer calls purchase function on clone factory

    let contracts = await cloneFactory.getContractList();
    let contractAddress = contracts[contracts.length - 1];
    let purchaseContract = await cloneFactory
      .connect(buyer)
      .setPurchaseRentalContract(contractAddress, "123");
    await purchaseContract.wait();

    //seller closes out the contract and collects the lumerin tokens
    let contract1 = await Implementation.attach(contractAddress);
    let sellerBeforeCloseout = await lumerin.balanceOf(seller.address);
    sleep.sleep(contract_length);
    let closeOut = await contract1.connect(seller).setContractCloseOut(2);
    await closeOut.wait();
    let sellerAfterCloseout = await lumerin.balanceOf(seller.address);
    expect(
      Number(sellerAfterCloseout) - Number(sellerBeforeCloseout),
      `expected the seller to have ${sellerBeforeCloseout} tokens but seller actually has ${sellerAfterCloseout}`
    ).to.equal(0);
  });

  it("standard purchase, refresh, and repurchase", async function () {
    //buyer calls purchase function on clone factory

    let contracts = await cloneFactory.getContractList();
    let contractAddress = contracts[contracts.length - 1];
    let purchaseContract = await cloneFactory
      .connect(buyer)
      .setPurchaseRentalContract(contractAddress, "123");
    await purchaseContract.wait();

    //seller closes out the contract and collects the lumerin tokens
    let contract1 = await Implementation.attach(contractAddress);
    let sellerBeforeCloseout = await lumerin.balanceOf(seller.address);
    sleep.sleep(contract_length);
    let closeOut = await contract1.connect(seller).setContractCloseOut(2);
    await closeOut.wait();
    //check to see if the contract is closed out here
    let sellerAfterCloseout = await lumerin.balanceOf(seller.address);
    expect(Number(sellerAfterCloseout) - Number(sellerBeforeCloseout)).to.equal(
      0
    );
    //purchasing the contract a second time
    purchaseContract = await cloneFactory
      .connect(buyer)
      .setPurchaseRentalContract(contractAddress, "123");
    purchaseContract.wait();
    //confirm the contract is in a purchased state
  });

  it("standard purchase, refresh, repurchase, and withdraw tokens midway", async function () {
    let contracts = await cloneFactory.getContractList();
    let contractAddress = contracts[contracts.length - 1];
    let purchaseContract = await cloneFactory
      .connect(buyer)
      .setPurchaseRentalContract(contractAddress, "123");
    await purchaseContract.wait();

    let contract1 = await Implementation.attach(contractAddress);
    let sellerBeforeCloseout = await lumerin.balanceOf(seller.address);
    sleep.sleep(contract_length);
    let closeOut = await contract1.connect(seller).setContractCloseOut(2);
    await closeOut.wait();
    purchaseContract = await cloneFactory
      .connect(buyer)
      .setPurchaseRentalContract(contractAddress, "123");
    await purchaseContract.wait();
    sleep.sleep(Number(contract_length / 2));
    let secondCloseOut = await contract1.connect(seller).setContractCloseOut(1);
    await secondCloseOut.wait();
    let sellerAfterCloseout = await lumerin.balanceOf(seller.address);
    expect(
      Number(sellerAfterCloseout) - Number(sellerBeforeCloseout)
    ).to.be.within(purchase_price + 1, purchase_price * 2 - 1);
  });

  it("contract is purchased, buyer updated routing information", async function () {
    let contracts = await cloneFactory.getContractList();
    let purchaseContract = await cloneFactory
      .connect(buyer)
      .setPurchaseRentalContract(contracts[contracts.length - 1], "123");
    await purchaseContract.wait();

    //buyer updates the mining information
    let contract1 = await Implementation.attach(
      contracts[contracts.length - 1]
    );
    let updateInfo = await contract1
      .connect(buyer)
      .setUpdateMiningInformation("meow");
    await updateInfo.wait();
    //confirm purchase info is updated
    let poolData = await contract1.encryptedPoolData();
    expect(poolData).to.be.equal("meow");
  });

  it("contract is available, seller updates purchase information and withdraws tokens", async function () {
    //buyer calls purchase function on clone factory

    //let implementationABI = await hre.artifacts.readArtifact("contracts/Implementation.sol:Implementation")
    let contracts = await cloneFactory.getContractList();
    let purchaseContract = await cloneFactory
      .connect(buyer)
      .setPurchaseRentalContract(contracts[contracts.length - 1], "123");
    let contract1 = await Implementation.attach(
      contracts[contracts.length - 1]
    );
    await purchaseContract.wait();
    let sellerBeforeCloseout = await lumerin.balanceOf(seller.address);
    sleep.sleep(contract_length);
    let changeInfo = await contract1
      .connect(seller)
      .setUpdatePurchaseInformation(11, 12, 13, 14, 3);
    await changeInfo.wait();
    let sellerAfterCloseout = await lumerin.balanceOf(seller.address);
    expect(
      Number(sellerAfterCloseout) - Number(sellerBeforeCloseout),
      `expected the seller to have ${
        sellerBeforeCloseout + purchase_price
      } but seller has ${sellerAfterCloseout}`
    ).to.equal(purchase_price);
    let updatedPrice = await contract1.price();
    let updatedLimit = await contract1.limit();
    let updatedSpeed = await contract1.speed();
    let updatedLength = await contract1.length();
    expect(updatedPrice).to.be.equal("11");
    expect(updatedLimit).to.be.equal("12");
    expect(updatedSpeed).to.be.equal("13");
    expect(updatedLength).to.be.equal("14");
  });

  it("standard purchase, seller cashes out 1/4 of the way through and confirm that they get that amount", async function() {
    //buyer calls purchase function on clone factory

    let contracts = await cloneFactory.getContractList();
    let contractAddress = contracts[contracts.length - 1];
    let purchaseContract = await cloneFactory
      .connect(buyer)
      .setPurchaseRentalContract(contractAddress, "123");
    await purchaseContract.wait();
    //seller closes out the contract and collects the lumerin tokens
    let contract1 = await Implementation.attach(contractAddress);
    let sellerBeforeCloseout = await lumerin.balanceOf(seller.address);
    let buyerBeforeCloseout = await lumerin.balanceOf(buyer.address);
    sleep.msleep(1000);
    let closeOut = await contract1.connect(buyer).setContractCloseOut(0);
    await closeOut.wait();
    let sellerAfterCloseout = await lumerin.balanceOf(seller.address);
    let buyerAfterCloseout = await lumerin.balanceOf(buyer.address);
    sellerBeforeCloseout = Number(sellerBeforeCloseout);
    sellerAfterCloseout = Number(sellerAfterCloseout);
    buyerBeforeCloseout = Number(buyerBeforeCloseout);
    buyerAfterCloseout = Number(buyerAfterCloseout);
    expect(
      Number(sellerAfterCloseout) - Number(sellerBeforeCloseout)
    ).to.be.within(1, Number(purchase_price / 2));
    expect(
      Number(buyerAfterCloseout) - Number(buyerBeforeCloseout)
    ).to.be.within(Number(purchase_price / 2), Number(purchase_price));
  });

  it("standard purchase, buyer cashes out 1/4 of the way through. Confirm buyer and seller amounts", async function () {
    //buyer calls purchase function on clone factory

    let contracts = await cloneFactory.getContractList();
    let contractAddress = contracts[contracts.length - 1];
    let purchaseContract = await cloneFactory
      .connect(buyer)
      .setPurchaseRentalContract(contractAddress, "123");
    await purchaseContract.wait();
    //seller closes out the contract and collects the lumerin tokens
    let contract1 = await Implementation.attach(contractAddress);
    let sellerBeforeCloseout = await lumerin.balanceOf(seller.address);
    let buyerBeforeCloseout = await lumerin.balanceOf(buyer.address);
    sleep.msleep(1000);
    let closeOut = await contract1.connect(buyer).setContractCloseOut(0);
    await closeOut.wait();
    let sellerAfterCloseout = await lumerin.balanceOf(seller.address);
    let buyerAfterCloseout = await lumerin.balanceOf(buyer.address);
    sellerBeforeCloseout = Number(sellerBeforeCloseout);
    sellerAfterCloseout = Number(sellerAfterCloseout);
    buyerBeforeCloseout = Number(buyerBeforeCloseout);
    buyerAfterCloseout = Number(buyerAfterCloseout);
    expect(
      Number(sellerAfterCloseout) - Number(sellerBeforeCloseout)
    ).to.be.within(1, Number(purchase_price / 2));
    expect(
      Number(buyerAfterCloseout) - Number(buyerBeforeCloseout)
    ).to.be.within(Number(purchase_price / 2), Number(purchase_price));
  });

  it("standard purchase, seller cashes out half way through contract and at end of contract", async function () {
    //buyer calls purchase function on clone factory

    let contracts = await cloneFactory.getContractList();
    let contractAddress = contracts[contracts.length - 1];
    let purchaseContract = await cloneFactory
      .connect(buyer)
      .setPurchaseRentalContract(contractAddress, "123");
    await purchaseContract.wait();
    //seller closes out the contract and collects the lumerin tokens
    let contract1 = await Implementation.attach(contractAddress);
    let sellerBeforeCloseout = await lumerin.balanceOf(seller.address);
    sleep.sleep(Number(contract_length / 2));
    let closeOut = await contract1.connect(seller).setContractCloseOut(1);
    await closeOut.wait();
    sleep.sleep(Number(contract_length / 2));
    try {
      closeOut = await contract1.connect(seller).setContractCloseOut(3);
    } catch (err) {
      console.log(err);
    }
    await closeOut.wait();
    let sellerAfterCloseout = await lumerin.balanceOf(seller.address);
    expect(
      Number(sellerAfterCloseout) - Number(sellerBeforeCloseout),
      `expected the seller to have ${
        sellerBeforeCloseout + purchase_price
      } but seller has ${sellerAfterCloseout}`
    ).to.equal(purchase_price);
  });

  it("standard purchase, refresh, repurchase, and buyer calls close out after contract is complete", async function () {
    let contracts = await cloneFactory.getContractList();
    let contractAddress = contracts[contracts.length - 1];
    let sellerBeforeCloseout = await lumerin.balanceOf(seller.address);
    let buyerBeforeCloseout = await lumerin.balanceOf(buyer.address);
    let purchaseContract = await cloneFactory
      .connect(buyer)
      .setPurchaseRentalContract(contractAddress, "123");
    await purchaseContract.wait();
    let contract1 = await Implementation.attach(contractAddress);
    sleep.sleep(contract_length);
    let closeOut = await contract1.connect(seller).setContractCloseOut(2);
    await closeOut.wait();
    let contractBalance = await lumerin.balanceOf(contractAddress);
    expect(Number(contractBalance)).to.be.equal(purchase_price);
    purchaseContract = await cloneFactory
      .connect(buyer)
      .setPurchaseRentalContract(contractAddress, "123");
    await purchaseContract.wait();
    contractBalance = await lumerin.balanceOf(contractAddress);
    expect(Number(contractBalance)).to.be.equal(purchase_price * 2);
    let buyerAfterCloseout = await lumerin.balanceOf(buyer.address);
    expect(
      Number(buyerAfterCloseout) - Number(buyerBeforeCloseout)
    ).to.be.equal(-purchase_price * 2);
    sleep.sleep(contract_length);
    let secondCloseOut = await contract1.connect(buyer).setContractCloseOut(0);
    await secondCloseOut.wait();
    expect(Number(contractBalance)).to.be.equal(purchase_price * 2);
    let sellerAfterCloseout = await lumerin.balanceOf(seller.address);
    buyerAfterCloseout = await lumerin.balanceOf(buyer.address);
    expect(
      Number(sellerAfterCloseout) - Number(sellerBeforeCloseout)
    ).to.be.equal(0);
    expect(
      Number(buyerAfterCloseout) - Number(buyerBeforeCloseout)
    ).to.be.equal(-purchase_price * 2);
    let thirdCloseOut = await contract1.connect(seller).setContractCloseOut(1);
    await thirdCloseOut.wait();
    contractBalance = await lumerin.balanceOf(contractAddress);
    expect(Number(contractBalance)).to.be.equal(0);
    sellerAfterCloseout = await lumerin.balanceOf(seller.address);
    buyerAfterCloseout = await lumerin.balanceOf(buyer.address);
    expect(
      Number(buyerAfterCloseout) - Number(buyerBeforeCloseout)
    ).to.be.equal(-purchase_price * 2);
    expect(
      Number(sellerAfterCloseout) - Number(sellerBeforeCloseout)
    ).to.be.equal(purchase_price * 2);
  });

  it("confirm that the return variables function returns all expected variables", async function () {
    let contracts = await cloneFactory.getContractList();
    let contractAddress = contracts[contracts.length - 1];
    let contract1 = await Implementation.attach(contractAddress);
    let contractVariables = await contract1.getPublicVariables();
    expect(contractVariables[0]).to.be.equal(0);
    expect(contractVariables[1]).to.be.equal(String(purchase_price));
    expect(contractVariables[2]).to.be.equal("10");
    expect(contractVariables[3]).to.be.equal("10");
    expect(contractVariables[4]).to.be.equal("10");
  });

  it("standard purchase and withdrawl with titan withdrawl on", async function () {
    //buyer calls purchase function on clone factory
    let isCut = await cloneFactory.setTitanCut(true);
    await isCut.wait();
    let titanBeforeCloseout = await lumerin.balanceOf(validator.address);
    let contracts = await cloneFactory.getContractList();
    let contractAddress = contracts[contracts.length - 1];
    let purchaseContract = await cloneFactory
      .connect(buyer)
      .setPurchaseRentalContract(contractAddress, "123");
    await purchaseContract.wait();
    //seller closes out the contract and collects the lumerin tokens
    let contract1 = await Implementation.attach(contractAddress);
    let sellerBeforeCloseout = await lumerin.balanceOf(seller.address);
    sleep.sleep(contract_length);
    let closeOut = await contract1.connect(seller).setContractCloseOut(3);
    await closeOut.wait();
    let sellerAfterCloseout = await lumerin.balanceOf(seller.address);
    let titanAfterCloseout = await lumerin.balanceOf(validator.address);
    expect(
      Number(sellerAfterCloseout) - Number(sellerBeforeCloseout),
      `expected the seller to have ${
        sellerBeforeCloseout + purchase_price
      } but seller has ${sellerAfterCloseout}`
    ).to.equal(purchase_price * 0.975);
    expect(
      Number(titanAfterCloseout) - Number(titanBeforeCloseout),
      `expected the titan to have ${
        titanBeforeCloseout + purchase_price
      } but titan has ${titanAfterCloseout}`
    ).to.equal(purchase_price * 0.025);
  });

  it("standard purchase and withdrawl type 2 with titan withdrawl on", async function () {
    //buyer calls purchase function on clone factory
    let isCut = await cloneFactory.setTitanCut(true);
    await isCut.wait();
    let titanBeforeCloseout = await lumerin.balanceOf(validator.address);
    let contracts = await cloneFactory.getContractList();
    let contractAddress = contracts[contracts.length - 1];
    let purchaseContract = await cloneFactory
      .connect(buyer)
      .setPurchaseRentalContract(contractAddress, "123");
    await purchaseContract.wait();
    //seller closes out the contract and collects the lumerin tokens
    let contract1 = await Implementation.attach(contractAddress);
    let sellerBeforeCloseout = await lumerin.balanceOf(seller.address);
    sleep.sleep(contract_length);
    let closeOut = await contract1.connect(seller).setContractCloseOut(2);
    await closeOut.wait();
    let sellerAfterCloseout = await lumerin.balanceOf(seller.address);
    let titanAfterCloseout = await lumerin.balanceOf(validator.address);
    expect(
      Number(sellerAfterCloseout) - Number(sellerBeforeCloseout),
      `expected the seller to have ${
        sellerBeforeCloseout + purchase_price
      } but seller has ${sellerAfterCloseout}`
    ).to.equal(0);
    expect(
      Number(titanAfterCloseout) - Number(titanBeforeCloseout),
      `expected the titan to have ${
        titanBeforeCloseout + purchase_price
      } but titan has ${titanAfterCloseout}`
    ).to.equal(purchase_price * 0.025);
  });

  it("purchase purchase withdrawl type 3 with titan withdrawl on", async function () {
    //buyer calls purchase function on clone factory
    let isCut = await cloneFactory.setTitanCut(true);
    await isCut.wait();
    let titanBeforeCloseout = await lumerin.balanceOf(validator.address);
    let contracts = await cloneFactory.getContractList();
    let contractAddress = contracts[contracts.length - 1];
    let purchaseContract = await cloneFactory
      .connect(buyer)
      .setPurchaseRentalContract(contractAddress, "123");
    await purchaseContract.wait();
    //seller closes out the contract and collects the lumerin tokens
    let contract1 = await Implementation.attach(contractAddress);
    let sellerBeforeCloseout = await lumerin.balanceOf(seller.address);
    sleep.sleep(contract_length);
    let closeOut = await contract1.connect(seller).setContractCloseOut(3);
    await closeOut.wait();
    let sellerAfterCloseout = await lumerin.balanceOf(seller.address);
    let titanAfterCloseout = await lumerin.balanceOf(validator.address);
    expect(
      Number(sellerAfterCloseout) - Number(sellerBeforeCloseout),
      `expected the seller to have ${
        sellerBeforeCloseout + purchase_price
      } but seller has ${sellerAfterCloseout}`
    ).to.equal(purchase_price * 0.975);
    expect(
      Number(titanAfterCloseout) - Number(titanBeforeCloseout),
      `expected the titan to have ${
        titanBeforeCloseout + purchase_price
      } but titan has ${titanAfterCloseout}`
    ).to.equal(purchase_price * 0.025);
    purchaseContract = await cloneFactory
      .connect(buyer)
      .setPurchaseRentalContract(contractAddress, "123");
    await purchaseContract.wait();
    //seller closes out the contract and collects the lumerin tokens
    sleep.sleep(contract_length);
    closeOut = await contract1.connect(seller).setContractCloseOut(3);
    await closeOut.wait();
    sellerAfterCloseout = await lumerin.balanceOf(seller.address);
    titanAfterCloseout = await lumerin.balanceOf(validator.address);
    sellerAfterCloseout = Number(sellerAfterCloseout);
    titanAfterCloseout = Number(titanAfterCloseout);
    expect(
      Number(sellerAfterCloseout) - Number(sellerBeforeCloseout),
      `expected the seller to have ${
        Number(sellerBeforeCloseout) + purchase_price
      } but seller has ${sellerAfterCloseout}`
    ).to.equal(purchase_price * 0.975 * 2);
    expect(
      Number(titanAfterCloseout) - Number(titanBeforeCloseout),
      `expected the titan to have ${
        Number(titanBeforeCloseout) + purchase_price
      } but titan has ${titanAfterCloseout}`
    ).to.equal(purchase_price * 0.025 * 2);
  });

  it("standard purchase, buyer cancels half way through, seller collects owed funds", async function () {
    //buyer calls purchase function on clone factory

    let isCut = await cloneFactory.setTitanCut(true);
    await isCut.wait();
    let contracts = await cloneFactory.getContractList();
    let contractAddress = contracts[contracts.length - 1];
    let purchaseContract = await cloneFactory
      .connect(buyer)
      .setPurchaseRentalContract(contractAddress, "123");
    let sellerBeforePurchase = await lumerin.balanceOf(seller.address);
    await purchaseContract.wait();
    let buyerAfterPurchase = await lumerin.balanceOf(buyer.address);
    //seller closes out the contract and collects the lumerin tokens
    let contract1 = await Implementation.attach(contractAddress);
    sleep.msleep(Number(contract_length / 4) * 1000);
    let closeOut = await contract1.connect(buyer).setContractCloseOut(0);
    await closeOut.wait();
    let buyerAfterCloseout = await lumerin.balanceOf(buyer.address);
    expect(
      Number(buyerAfterCloseout),
      `expected the buyer to have more than ${buyerAfterPurchase} but buyer has ${buyerAfterCloseout}`
    ).to.be.above(buyerAfterPurchase);
    closeOut = await contract1.connect(seller).setContractCloseOut(3);
    await closeOut.wait();
    let sellerAfterCloseout = await lumerin.balanceOf(seller.address);
    expect(
      Number(sellerAfterCloseout) - Number(sellerBeforePurchase),
      ``
    ).to.be.below(purchase_price * 0.975 * 0.75);
  });

  //it("", async function () {});

  //it("", async function () {});
  //it("", async function () {});
  //it("", async function () {});
});
