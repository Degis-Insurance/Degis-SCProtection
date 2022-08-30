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
} from "../typechain-types";
import { parseUnits } from "ethers/lib/utils";

task("setAllAddress", "Set all addresses").setAction(async (_, hre) => {
  await hre.run("setProtectionPool");

  await hre.run("setPriorityPoolFactory");

  await hre.run("setIncidentReport");

  await hre.run("setOnboardProposal");

  await hre.run("setPolicyCenter");

  await hre.run("setExecutor");

  await hre.run("setFarmingPool");
});

task("setProtectionPool", "Set contract address in protectionPool").setAction(
  async (_, hre) => {
    console.log("\nSetting contract addresses in reinsurance pool\n");

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
  "Set contract address in insurancePoolFactory"
).setAction(async (_, hre) => {
  console.log("\nSetting contract addresses in insurancePoolFactory\n");

  const { network } = hre;

  // Signers
  const [dev_account] = await hre.ethers.getSigners();
  console.log("The default signer is: ", dev_account.address);

  const addressList = readAddressList();

  const executorAddress = addressList[network.name].Executor;
  const policyCenterAddress = addressList[network.name].PolicyCenter;
  const premiumRewardPoolAddress = addressList[network.name].PremiumRewardPool;
  const weightedFarmingPoolAddress =
    addressList[network.name].WeightedFarmingPool;
  const incidentReportAddress = addressList[network.name].IncidentReport;
  const payoutPoolAddress = addressList[network.name].PayoutPool;

  const priorityPoolFactory: PriorityPoolFactory =
    new PriorityPoolFactory__factory(dev_account).attach(
      addressList[network.name].PriorityPoolFactory
    );

  const tx_1 = await priorityPoolFactory.setPolicyCenter(policyCenterAddress);
  console.log("Tx details: ", await tx_1.wait());

  const tx_2 = await priorityPoolFactory.setExecutor(executorAddress);
  console.log("Tx details: ", await tx_2.wait());

  const tx_3 = await priorityPoolFactory.setPremiumRewardPool(
    premiumRewardPoolAddress
  );
  console.log("Tx details: ", await tx_3.wait());

  const tx_4 = await priorityPoolFactory.setWeightedFarmingPool(
    weightedFarmingPoolAddress
  );
  console.log("Tx details: ", await tx_4.wait());

  const tx_5 = await priorityPoolFactory.setIncidentReport(
    incidentReportAddress
  );
  console.log("Tx details: ", await tx_5.wait());

  const tx_6 = await priorityPoolFactory.setPayoutPool(payoutPoolAddress);
  console.log("Tx details: ", await tx_6.wait());

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
      addressList[network.name].InsurancePoolFactory;

    const incidentReport: IncidentReport = new IncidentReport__factory(
      dev_account
    ).attach(addressList[network.name].IncidentReport);

    if (
      (await incidentReport.priorityPoolFactory()) != priorityPoolFactoryAddress
    ) {
      const tx = await incidentReport.setPriorityPoolFactory(
        priorityPoolFactoryAddress
      );
      console.log("Tx details: ", await tx.wait());
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
      addressList[network.name].InsurancePoolFactory;

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
    const exchangeAddress = addressList[network.name].MockExchange;
    const priceGetterAddress = addressList[network.name].PriceGetter;
    const crTokenFactoryAddress =
      addressList[network.name].CoverRightTokenFactory;
    const weightedFarmingPoolAddress =
      addressList[network.name].WeightedFarmingPool;
    const payoutPoolAddress = addressList[network.name].PayoutPool;
    const treasuryAddress = addressList[network.name].Treasury;

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
      console.log("Tx details: ", await tx_4.wait());
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

    if ((await executor.treasury()) != treasuryAddress) {
      const tx_4 = await executor.setOnboardProposal(treasuryAddress);
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

    const weightedFarmingPool: WeightedFarmingPool =
      new WeightedFarmingPool__factory(dev_account).attach(
        addressList[network.name].WeightedFarmingPool
      );

    if ((await weightedFarmingPool.policyCenter()) != policyCenterAddress) {
      const tx_1 = await weightedFarmingPool.setPolicyCenter(
        policyCenterAddress
      );
      console.log("Tx details: ", await tx_1.wait());
    }

    console.log("\nFinish setting contract addresses in farming pool\n");
  }
);

task("mintToken").setAction(async (_, hre) => {
  const { network } = hre;

  // Signers
  const [dev_account] = await hre.ethers.getSigners();
  console.log("The default signer is: ", dev_account.address);

  const addressList = readAddressList();

  const deg: MockDEG = new MockDEG__factory(dev_account).attach(
    addressList[network.name].MockDEG
  );

  const tx = await deg.mintDegis(dev_account.address, parseUnits("10000"));
  console.log("tx details", await tx.wait());
});
