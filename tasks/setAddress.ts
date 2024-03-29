import { task, types } from "hardhat/config";
import "@nomiclabs/hardhat-ethers";

import { readAddressList } from "../scripts/contractAddress";
import {
  Executor,
  Executor__factory,
  IncidentReport,
  IncidentReport__factory,
  PriorityPoolFactory,
  PriorityPoolFactory__factory,
  OnboardProposal,
  OnboardProposal__factory,
  PolicyCenter,
  PolicyCenter__factory,
  ProtectionPool,
  ProtectionPool__factory,
  WeightedFarmingPool,
  WeightedFarmingPool__factory,
  PriorityPool,
  PriorityPool__factory,
  MockSHIELD,
  MockSHIELD__factory,
  MockUSDC,
  MockUSDC__factory,
  CoverRightToken,
  CoverRightToken__factory,
  CoverRightTokenFactory__factory,
  CoverRightTokenFactory,
  PriorityPoolDeployer,
  PriorityPoolDeployer__factory,
  PriceGetter,
  PriceGetter__factory,
  Treasury,
  Treasury__factory,
  DexPriceGetter,
  DexPriceGetter__factory,
  MockERC20__factory,
} from "../typechain-types";
import { formatUnits, parseUnits } from "ethers/lib/utils";

task("setAllAddress", "Set all addresses").setAction(async (_, hre) => {
  await hre.run("setProtectionPool");

  await hre.run("setPriorityPoolFactory");

  await hre.run("setIncidentReport");

  await hre.run("setOnboardProposal");

  await hre.run("setPolicyCenter");

  await hre.run("setExecutor");

  await hre.run("setFarmingPool");

  await hre.run("setCRFactory");
});

task("setProtectionPool", "Set contract address in protectionPool").setAction(
  async (_, hre) => {
    console.log("\nSetting contract addresses in protection pool\n");

    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    // Addresses to be set
    const priorityPoolFactoryAddress =
      addressList[network.name].PriorityPoolFactory;
    const incidentReportAddress = addressList[network.name].IncidentReport;
    const policyCenterAddress = addressList[network.name].PolicyCenter;

    const protectionPool: ProtectionPool = new ProtectionPool__factory(
      dev_account
    ).attach(addressList[network.name].ProtectionPool);

    if ((await protectionPool.policyCenter()) != policyCenterAddress) {
      const tx_1 = await protectionPool.setPolicyCenter(policyCenterAddress);
      console.log("Tx details: ", await tx_1.wait());
    }

    if (
      (await protectionPool.priorityPoolFactory()) != priorityPoolFactoryAddress
    ) {
      const tx_2 = await protectionPool.setPriorityPoolFactory(
        priorityPoolFactoryAddress
      );
      console.log("Tx details: ", await tx_2.wait());
    }

    if ((await protectionPool.incidentReport()) != incidentReportAddress) {
      const tx_3 = await protectionPool.setIncidentReport(
        incidentReportAddress
      );
      console.log("Tx details: ", await tx_3.wait());
    }

    console.log("\nFinish setting contract addresses in protection pool\n");
  }
);

task(
  "setPriorityPoolFactory",
  "Set contract address in priorityPoolFactory"
).setAction(async (_, hre) => {
  console.log("\nSetting contract addresses in priorityPoolFactory\n");

  const { network } = hre;

  // Signers
  const [dev_account] = await hre.ethers.getSigners();
  console.log("The default signer is: ", dev_account.address);

  const addressList = readAddressList();

  const executorAddress = addressList[network.name].Executor;
  const policyCenterAddress = addressList[network.name].PolicyCenter;
  const weightedFarmingPoolAddress =
    addressList[network.name].WeightedFarmingPool;
  const incidentReportAddress = addressList[network.name].IncidentReport;
  const priorityPoolDeployerAddress =
    addressList[network.name].PriorityPoolDeployer;

  const priorityPoolFactory: PriorityPoolFactory =
    new PriorityPoolFactory__factory(dev_account).attach(
      addressList[network.name].PriorityPoolFactory
    );

  if ((await priorityPoolFactory.policyCenter()) != policyCenterAddress) {
    const tx_1 = await priorityPoolFactory.setPolicyCenter(policyCenterAddress);
    console.log("Tx details: ", await tx_1.wait());
  }

  if ((await priorityPoolFactory.executor()) != executorAddress) {
    const tx_2 = await priorityPoolFactory.setExecutor(executorAddress);
    console.log("Tx details: ", await tx_2.wait());
  }

  if (
    (await priorityPoolFactory.weightedFarmingPool()) !=
    weightedFarmingPoolAddress
  ) {
    const tx_3 = await priorityPoolFactory.setWeightedFarmingPool(
      weightedFarmingPoolAddress
    );
    console.log("Tx details: ", await tx_3.wait());
  }

  if ((await priorityPoolFactory.incidentReport()) != incidentReportAddress) {
    const tx_4 = await priorityPoolFactory.setIncidentReport(
      incidentReportAddress
    );
    console.log("Tx details: ", await tx_4.wait());
  }

  if (
    (await priorityPoolFactory.priorityPoolDeployer()) !=
    priorityPoolDeployerAddress
  ) {
    const tx_5 = await priorityPoolFactory.setPriorityPoolDeployer(
      priorityPoolDeployerAddress
    );
    console.log("Tx details: ", await tx_5.wait());
  }

  console.log("\nFinish setting contract addresses in priority pool factory\n");
});

task("setIncidentReport", "Set contract address in incident report").setAction(
  async (_, hre) => {
    console.log("\nSetting contract addresses in incident report\n");

    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const priorityPoolFactoryAddress =
      addressList[network.name].PriorityPoolFactory;
    const executorAddress = addressList[network.name].Executor;

    const incidentReport: IncidentReport = new IncidentReport__factory(
      dev_account
    ).attach(addressList[network.name].IncidentReport);

    if (
      (await incidentReport.priorityPoolFactory()) != priorityPoolFactoryAddress
    ) {
      const tx_1 = await incidentReport.setPriorityPoolFactory(
        priorityPoolFactoryAddress
      );
      console.log("Tx details: ", await tx_1.wait());
    }

    if ((await incidentReport.executor()) != executorAddress) {
      const tx_2 = await incidentReport.setExecutor(executorAddress);
      console.log("Tx details: ", await tx_2.wait());
    }

    console.log("\nFinish setting contract addresses in incident report\n");
  }
);

task("setOnboardProposal", "Set contract address in onboardProposal").setAction(
  async (_, hre) => {
    console.log("\nSetting contract addresses in onbardproposal\n");

    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const priorityPoolFactoryAddress =
      addressList[network.name].PriorityPoolFactory;

    const onboardProposal: OnboardProposal = new OnboardProposal__factory(
      dev_account
    ).attach(addressList[network.name].OnboardProposal);

    if (
      (await onboardProposal.priorityPoolFactory()) !=
      priorityPoolFactoryAddress
    ) {
      const tx = await onboardProposal.setPriorityPoolFactory(
        priorityPoolFactoryAddress
      );
      console.log("Tx details: ", await tx.wait());
    }

    console.log("\nFinish setting contract addresses in onboard proposal\n");
  }
);

task("setPolicyCenter", "Set contract address in policyCenter").setAction(
  async (_, hre) => {
    console.log("\nSetting contract addresses in policy center \n");

    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const priorityPoolFactoryAddress =
      addressList[network.name].PriorityPoolFactory;
    const protectionPoolAddress = addressList[network.name].ProtectionPool;
    const exchangeAddress =
      network.name != "avax" &&
      network.name != "avaxTest" &&
      network.name != "avaxNew"
        ? addressList[network.name].MockExchange
        : addressList[network.name].Exchange;
    const priceGetterAddress =
      network.name != "avax" &&
      network.name != "avaxTest" &&
      network.name != "avaxNew"
        ? addressList[network.name].MockPriceGetter
        : addressList[network.name].PriceGetter;
    const crTokenFactoryAddress =
      addressList[network.name].CoverRightTokenFactory;
    const weightedFarmingPoolAddress =
      addressList[network.name].WeightedFarmingPool;
    const payoutPoolAddress = addressList[network.name].PayoutPool;
    const treasuryAddress = addressList[network.name].Treasury;
    const dexPriceGetterAddress = addressList[network.name].DexPriceGetter;

    const policyCenter: PolicyCenter = new PolicyCenter__factory(
      dev_account
    ).attach(addressList[network.name].PolicyCenter);

    if (
      (await policyCenter.priorityPoolFactory()) != priorityPoolFactoryAddress
    ) {
      const tx_1 = await policyCenter.setPriorityPoolFactory(
        priorityPoolFactoryAddress
      );
      console.log("Tx details: ", await tx_1.wait());
    }

    if ((await policyCenter.protectionPool()) != protectionPoolAddress) {
      const tx_2 = await policyCenter.setProtectionPool(protectionPoolAddress);
      console.log("Tx details: ", await tx_2.wait());
    }

    if ((await policyCenter.exchange()) != exchangeAddress) {
      const tx_3 = await policyCenter.setExchange(exchangeAddress);
      console.log("Tx details: ", await tx_3.wait());
    }

    if ((await policyCenter.priceGetter()) != priceGetterAddress) {
      const tx_4 = await policyCenter.setPriceGetter(priceGetterAddress);
      console.log("Tx details getter: ", await tx_4.wait());
    }

    if (
      (await policyCenter.coverRightTokenFactory()) != crTokenFactoryAddress
    ) {
      const tx_5 = await policyCenter.setCoverRightTokenFactory(
        crTokenFactoryAddress
      );
      console.log("Tx details: ", await tx_5.wait());
    }

    if (
      (await policyCenter.weightedFarmingPool()) != weightedFarmingPoolAddress
    ) {
      const tx_6 = await policyCenter.setWeightedFarmingPool(
        weightedFarmingPoolAddress
      );
      console.log("Tx details: ", await tx_6.wait());
    }

    if ((await policyCenter.payoutPool()) != payoutPoolAddress) {
      const tx_7 = await policyCenter.setPayoutPool(payoutPoolAddress);
      console.log("Tx details: ", await tx_7.wait());
    }

    if ((await policyCenter.treasury()) != treasuryAddress) {
      const tx_8 = await policyCenter.setTreasury(treasuryAddress);
      console.log("Tx details: ", await tx_8.wait());
    }

    // if ((await policyCenter.dexPriceGetter()) != dexPriceGetterAddress) {
    //   const tx_9 = await policyCenter.setDexPriceGetter(dexPriceGetterAddress);
    //   console.log("Tx details: ", await tx_9.wait());
    // }

    console.log("\nFinish setting contract addresses in policy center\n");
  }
);

task("setExecutor", "Set contract address in executor").setAction(
  async (_, hre) => {
    console.log("\nSetting contract addresses in executor\n");

    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const treasuryAddress = addressList[network.name].Treasury;
    const priorityPoolFactoryAddress =
      addressList[network.name].PriorityPoolFactory;
    const incidentReportAddress = addressList[network.name].IncidentReport;
    const onboardProposalAddress = addressList[network.name].OnboardProposal;

    const executor: Executor = new Executor__factory(dev_account).attach(
      addressList[network.name].Executor
    );

    if ((await executor.priorityPoolFactory()) != priorityPoolFactoryAddress) {
      const tx_1 = await executor.setPriorityPoolFactory(
        priorityPoolFactoryAddress
      );
      console.log("Tx details: ", await tx_1.wait());
    }

    if ((await executor.incidentReport()) != incidentReportAddress) {
      const tx_2 = await executor.setIncidentReport(incidentReportAddress);
      console.log("Tx details: ", await tx_2.wait());
    }

    if ((await executor.onboardProposal()) != onboardProposalAddress) {
      const tx_3 = await executor.setOnboardProposal(onboardProposalAddress);
      console.log("Tx details: ", await tx_3.wait());
    }

    console.log("proposal", await executor.onboardProposal());

    if ((await executor.treasury()) != treasuryAddress) {
      const tx_4 = await executor.setTreasury(treasuryAddress);
      console.log("Tx details: ", await tx_4.wait());
    }

    console.log("\nFinish setting contract addresses in executor\n");
  }
);

task("setFarmingPool", "Set address in weighted farming pool").setAction(
  async (_, hre) => {
    console.log("\nSetting contract addresses in executor\n");

    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const policyCenterAddress = addressList[network.name].PolicyCenter;
    const factoryAddress = addressList[network.name].PriorityPoolFactory;

    const weightedFarmingPool: WeightedFarmingPool =
      new WeightedFarmingPool__factory(dev_account).attach(
        addressList[network.name].WeightedFarmingPool
      );

    // if ((await weightedFarmingPool.policyCenter()) != policyCenterAddress) {
    //   const tx_1 = await weightedFarmingPool.setPolicyCenter(
    //     policyCenterAddress
    //   );
    //   console.log("Tx details: ", await tx_1.wait());
    // }

    // if ((await weightedFarmingPool.priorityPoolFactory()) != factoryAddress) {
    //   const tx_2 = await weightedFarmingPool.setPriorityPoolFactory(
    //     factoryAddress
    //   );
    //   console.log("Tx details: ", await tx_2.wait());
    // }

    console.log("\nFinish setting contract addresses in farming pool\n");
  }
);

task("setCRFactory", "Set cover right token factory").setAction(
  async (_, hre) => {
    console.log("\nSetting contract addresses in executor\n");

    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const policyCenterAddress = addressList[network.name].PolicyCenter;
    const incidentReportAddress = addressList[network.name].IncidentReport;
    const payoutPoolAddress = addressList[network.name].PayoutPool;

    const crFactory: CoverRightTokenFactory =
      new CoverRightTokenFactory__factory(dev_account).attach(
        addressList[network.name].CoverRightTokenFactory
      );

    // if ((await crFactory.policyCenter()) != policyCenterAddress) {
    //   const tx_1 = await crFactory.setPolicyCenter(policyCenterAddress);
    //   console.log("Tx details: ", await tx_1.wait());
    // }

    // if ((await crFactory.incidentReport()) != incidentReportAddress) {
    //   const tx_2 = await crFactory.setIncidentReport(incidentReportAddress);
    //   console.log("Tx details: ", await tx_2.wait());
    // }

    if ((await crFactory.payoutPool()) != payoutPoolAddress) {
      const tx_3 = await crFactory.setPayoutPool(payoutPoolAddress);
      console.log("Tx details: ", await tx_3.wait());
    }

    console.log(
      "\nFinish setting contract addresses in cover right token factory\n"
    );
  }
);

task("approveToken", "Approve token").setAction(async (_, hre) => {
  const { network } = hre;

  // Signers
  const [dev_account] = await hre.ethers.getSigners();
  console.log("The default signer is: ", dev_account.address);

  const addressList = readAddressList();

  const shield: MockSHIELD = new MockSHIELD__factory(dev_account).attach(
    addressList[network.name].MockShield
  );

  const tx = await shield.approve(
    addressList[network.name].PolicyCenter,
    parseUnits("1000000000", 6)
  );
  console.log("tx details", await tx.wait());
});

task("approvePROLP", "Approve pro lp token").setAction(async (_, hre) => {
  const { network } = hre;

  // Signers
  const [dev_account] = await hre.ethers.getSigners();
  console.log("The default signer is: ", dev_account.address);

  const addressList = readAddressList();

  const protectionPool: ProtectionPool = new ProtectionPool__factory(
    dev_account
  ).attach(addressList[network.name].ProtectionPool);

  const tx = await protectionPool.approve(
    addressList[network.name].PolicyCenter,
    parseUnits("1000000000", 6)
  );
  console.log("tx details", await tx.wait());
});

// task("coverPrice", "Calculate cover price").setAction(async (taskArgs, hre) => {
//   const { network } = hre;

//   // Signers
//   const [dev_account] = await hre.ethers.getSigners();
//   console.log("The default signer is: ", dev_account.address);

//   const addressList = readAddressList();

//   const factory: PriorityPoolFactory = new PriorityPoolFactory__factory(
//     dev_account
//   ).attach(addressList[network.name].PriorityPoolFactory);

//   const pool1Address = (await factory.pools(1)).poolAddress;

//   const priorityPool: PriorityPool = new PriorityPool__factory(
//     dev_account
//   ).attach(pool1Address);

//   const ratio = await priorityPool.dynamicPremiumRatio(parseUnits("10", 6));
//   console.log("ratio", ratio.toString());

//   const price = await priorityPool.coverPrice(parseUnits("10", 6), 1);
//   console.log("price", formatUnits(price.price, 6));
// });

task("setPolicyCenterForCR", "Set policy center for cr token").setAction(
  async (_, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const crFactory: CoverRightTokenFactory =
      new CoverRightTokenFactory__factory(dev_account).attach(
        addressList[network.name].CoverRightTokenFactory
      );

    const strtime = "2022-11-1 07:59:59";
    const date = new Date(strtime);

    const timestamp = Math.floor(Number(date.getTime()) / 1000);

    const id = 1;
    const expiry = timestamp;
    const generation = 1;

    const crTokenAddress = await crFactory.getCRTokenAddress(
      id,
      expiry,
      generation
    );

    console.log("CR token address: ", crTokenAddress);

    const crToken: CoverRightToken = new CoverRightToken__factory(
      dev_account
    ).attach(crTokenAddress);

    const claimable = await crToken.getClaimableOf(dev_account.address);
    console.log("Claimable: ", claimable.toString());

    // const tx = await crToken.setPolicyCenter(hre.ethers.constants.AddressZero);
    // console.log("Tx details: ", await tx.wait());

    const policyCenterAddress = await crToken.policyCenter();
    console.log("policy center address", policyCenterAddress);
  }
);

task("check").setAction(async (_, hre) => {
  const { network } = hre;

  // Signers
  const [dev_account] = await hre.ethers.getSigners();
  console.log("The default signer is: ", dev_account.address);

  const addressList = readAddressList();

  const treasury: Treasury = new Treasury__factory(dev_account).attach(
    addressList[network.name].Treasury
  );

  const tx = await treasury.policyCenter();
  console.log("tx details:", tx);
});

// Price Feed for AVAX
// Name: AVAX
// Address: 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7 (WAVAX)
// Feed: 0x0A77230d17318075983913bC2145DB16C7366156
// Decimals: 8

// npx hardhat addPriceFeed --network avaxNew --name AVAX --address 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7 --feed 0x0A77230d17318075983913bC2145DB16C7366156 --decimals 8
// npx hardhat addPriceFeed --network avaxNew --name WETH --address 0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB --feed 0x976B3D034E162d8bD72D6b9C989d545b839003b0 --decimals 8

task("addPriceFeed", "Add price feed in price getter")
  .addParam("name", "Token name", null, types.string)
  .addParam("address", "Token address", null, types.string)
  .addParam("feed", "Oracle feed address", null, types.string)
  .addParam("decimals", "Decimals of the price feed", null, types.int)
  .setAction(async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const priceGetter: PriceGetter = new PriceGetter__factory(
      dev_account
    ).attach(addressList[network.name].PriceGetter);

    const tx = await priceGetter.setPriceFeed(
      taskArgs.name,
      taskArgs.address,
      taskArgs.feed,
      taskArgs.decimals
    );
    console.log("Tx details: ", await tx.wait());
  });

// name: PTP
// Pair: 0xCDFD91eEa657cc2701117fe9711C9a4F61FEED23

// name: Vector
// Pair: 0x9ef0c12b787f90f59cbbe0b611b82d30cab92929

task("addDexPriceFeed")
  .addParam("name", "Token name", null, types.string)
  .addParam("pair", "Trader joe pair", null, types.string)
  .addOptionalParam("decimals", "Token decimals", "18", types.string)
  .addOptionalParam("interval", "Sample interval", 60, types.int)
  .setAction(async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const dexGetter: DexPriceGetter = new DexPriceGetter__factory(
      dev_account
    ).attach(addressList[network.name].DexPriceGetter);

    const tx = await dexGetter.addIDOPair(
      taskArgs.name,
      taskArgs.pair,
      taskArgs.decimals,
      taskArgs.interval
    );
    console.log("Tx details:", await tx.wait());
  });

task("setAddressToName")
  .addParam("address", "Token address", null, types.string)
  .addParam("name", "Token name", null, types.string)
  .setAction(async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const dexGetter: DexPriceGetter = new DexPriceGetter__factory(
      dev_account
    ).attach(addressList[network.name].DexPriceGetter);

    const tx = await dexGetter.setAddressToName(
      taskArgs.address,
      taskArgs.name
    );
    console.log("Tx details:", await tx.wait());
  });

task("setDexPriceGetter").setAction(async (_, hre) => {
  const { network } = hre;

  // Signers
  const [dev_account] = await hre.ethers.getSigners();
  console.log("The default signer is: ", dev_account.address);

  const addressList = readAddressList();

  const dexGetter = addressList[network.name].DexPriceGetter;

  const policyCenter: PolicyCenter = new PolicyCenter__factory(
    dev_account
  ).attach(addressList[network.name].PolicyCenter);

  const tx = await policyCenter.setDexPriceGetter(dexGetter);
  console.log("Tx details", await tx.wait());
});

task("setExchange").setAction(async (_, hre) => {
  const { network } = hre;

  // Signers
  const [dev_account] = await hre.ethers.getSigners();
  console.log("The default signer is: ", dev_account.address);

  const addressList = readAddressList();

  const GMX = "0x62edc0692BD897D2295872a9FFCac5425011c661";
  const JOE = "0x6e84a6216eA6dACC71eE8E6b0a5B7322EEbC0fDd"
  const PTP = "0x22d4002028f537599be9f666d1c4fa138522f9c8"
  const VTX = "0x5817D4F0b62A59b17f75207DA1848C2cE75e7AF4"
  const YAK = "0x59414b3089ce2AF0010e7523Dea7E2b35d776ec7"
  const BTCb = "0x152b9d0FdC40C096757F570A51E494bd4b943E50"
  const WETHe = "0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB"
  const JoeRouter = "0x60aE616a2155Ee3d9A68541Ba4544862310933d4";

  const USDC = "0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E";

  const policyCenter: PolicyCenter = new PolicyCenter__factory(
    dev_account
  ).attach(addressList[network.name].PolicyCenter);

  const tx = await policyCenter.setExchangeByToken(WETHe, JoeRouter);
  console.log("Tx details", await tx.wait());

  const exchangeByToken = await policyCenter.exchangeByToken(WETHe);
  console.log("Exchange by  token", exchangeByToken);

  const t = new MockERC20__factory(dev_account).attach(WETHe);

  // const tx = await policyCenter.approvePoolToken(GMX)

  const allowance = await t.allowance(
    addressList[network.name].PolicyCenter,
    JoeRouter
  );
  console.log("Allowance", allowance.toString());
});

task("liyang").setAction(async (_, hre) => {
  const { network } = hre;

  // Signers
  const [dev_account] = await hre.ethers.getSigners();
  console.log("The default signer is: ", dev_account.address);

  const addressList = readAddressList();

  const policyCenter: PolicyCenter = new PolicyCenter__factory(
    dev_account
  ).attach(addressList[network.name].PolicyCenter);

  const usdc = await policyCenter.USDC();
  console.log("USDC", usdc);

  const JOE = "0x6e84a6216eA6dACC71eE8E6b0a5B7322EEbC0fDd";

  const exchangeByToken = await policyCenter.exchangeByToken(JOE);
  console.log("Exchange by  token", exchangeByToken);
});
