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
  MockDEG,
  MockDEG__factory,
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
    const miningTokenAddress = addressList[network.name].MiningToken;

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

    if ((await protectionPool.miningToken()) != miningTokenAddress) {
      const tx_4 = await protectionPool.setMiningToken(miningTokenAddress);
      console.log("Tx details: ", await tx_4.wait());
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
    console.log("\nSetting contract addresses in onbardproposal\n");

    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const priorityPoolFactoryAddress =
      addressList[network.name].PriorityPoolFactory;
    const protectionPoolAddress = addressList[network.name].ProtectionPool;
    const exchangeAddress =
      network.name != "avax" && network.name != "avaxTest"
        ? addressList[network.name].MockExchange
        : addressList[network.name].Exchange;
    const priceGetterAddress =
      network.name != "avax" && network.name != "avaxTest"
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

    // if ((await policyCenter.protectionPool()) != protectionPoolAddress) {
    //   const tx_2 = await policyCenter.setProtectionPool(protectionPoolAddress);
    //   console.log("Tx details: ", await tx_2.wait());
    // }

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

task("coverPrice", "Calculate cover price").setAction(async (taskArgs, hre) => {
  const { network } = hre;

  // Signers
  const [dev_account] = await hre.ethers.getSigners();
  console.log("The default signer is: ", dev_account.address);

  const addressList = readAddressList();

  const factory: PriorityPoolFactory = new PriorityPoolFactory__factory(
    dev_account
  ).attach(addressList[network.name].PriorityPoolFactory);

  const pool1Address = (await factory.pools(1)).poolAddress;

  const priorityPool: PriorityPool = new PriorityPool__factory(
    dev_account
  ).attach(pool1Address);

  const ratio = await priorityPool.dynamicPremiumRatio(parseUnits("10", 6));
  console.log("ratio", ratio.toString());

  const price = await priorityPool.coverPrice(parseUnits("10", 6), 1);
  console.log("price", formatUnits(price.price, 6));
});

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

task("approvePolicyCenter").setAction(async (_, hre) => {
  const { network } = hre;

  // Signers
  const [dev_account] = await hre.ethers.getSigners();
  console.log("The default signer is: ", dev_account.address);

  const addressList = readAddressList();

  const policyCenter: PolicyCenter = new PolicyCenter__factory(
    dev_account
  ).attach(addressList[network.name].PolicyCenter);

  const tx = await policyCenter.approvePoolToken(
    addressList[network.name].XAVAToken
  );
  console.log("tx details:", await tx.wait());
});

task("addPriceFeed").setAction(async (_, hre) => {
  const { network } = hre;

  // Signers
  const [dev_account] = await hre.ethers.getSigners();
  console.log("The default signer is: ", dev_account.address);

  const addressList = readAddressList();

  const priceGetter: PriceGetter = new PriceGetter__factory(dev_account).attach(
    addressList[network.name].PriceGetter
  );

  const joe = "0x6e84a6216eA6dACC71eE8E6b0a5B7322EEbC0fDd";
  const feed = "0x02D35d3a8aC3e1626d3eE09A78Dd87286F5E8e3a";

  const tx = await priceGetter.setPriceFeed("JOE", joe, feed, 8);
  console.log("tx details:", await tx.wait());
});

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
