import { task, types } from "hardhat/config";
import "@nomiclabs/hardhat-ethers";

import {
  readAddressList,
  readPriorityPoolList,
  storePriorityPoolList,
} from "../../scripts/contractAddress";
import {
  MockVeDEG,
  MockVeDEG__factory,
  OnboardProposal,
  OnboardProposal__factory,
  PolicyCenter,
  PolicyCenter__factory,
  PriorityPool,
  PriorityPoolFactory,
  PriorityPoolFactory__factory,
  PriorityPool__factory,
  ProtectionPool,
  ProtectionPool__factory,
} from "../../typechain-types";
import { formatUnits, parseUnits } from "ethers/lib/utils";

task("deployPriorityPool", "Deploy a new priority pool by owner")
  .addParam("name", "Protocol name", null, types.string)
  .addParam("token", "Token address", null, types.string)
  .addParam("capacity", "Max capacity", null, types.string)
  .addParam("premium", "Premium ratio annually", null, types.string)
  .setAction(async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();
    const priorityPoolList = readPriorityPoolList();

    const factory: PriorityPoolFactory = new PriorityPoolFactory__factory(
      dev_account
    ).attach(addressList[network.name].PriorityPoolFactory);

    const tx = await factory.deployPool(
      taskArgs.name,
      taskArgs.token,
      taskArgs.capacity,
      taskArgs.premium
    );

    console.log("tx details", await tx.wait());

    const currentCounter = await factory.poolCounter();
    const poolInfo = await factory.pools(currentCounter);

    // Store the new farming pool
    const poolObject = {
      id: currentCounter.toString(),
      poolAddress: poolInfo.poolAddress,
      name: poolInfo.protocolName,
      token: poolInfo.protocolToken,
      premium: poolInfo.basePremiumRatio.toString(),
    };
    priorityPoolList[network.name][currentCounter.toString()] = poolObject;

    storePriorityPoolList(priorityPoolList);
  });

task("provideLiquidity", "Provide liquidity to protection pool").setAction(
  async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();
    const priorityPoolList = readPriorityPoolList();

    const protectionPool: ProtectionPool = new ProtectionPool__factory(
      dev_account
    ).attach(addressList[network.name].ProtectionPool);

    const center: PolicyCenter = new PolicyCenter__factory(dev_account).attach(
      addressList[network.name].PolicyCenter
    );

    const tx = await center.provideLiquidity(parseUnits("100", 6));
    console.log("Tx details: ", await tx.wait());
  }
);

task("stakeLiquidity", "Stake liquidity to priority pool").setAction(
  async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();
    const priorityPoolList = readPriorityPoolList();

    const center: PolicyCenter = new PolicyCenter__factory(dev_account).attach(
      addressList[network.name].PolicyCenter
    );

    const tx = await center.stakeLiquidity(1, parseUnits("10", 6));
    console.log("Tx details: ", await tx.wait());
  }
);

task("unstakeLiquidity", "UnStake liquidity from priority pool").setAction(
  async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();
    const priorityPoolList = readPriorityPoolList();

    const center: PolicyCenter = new PolicyCenter__factory(dev_account).attach(
      addressList[network.name].PolicyCenter
    );

    const factory: PriorityPoolFactory = new PriorityPoolFactory__factory(
      dev_account
    ).attach(addressList[network.name].PriorityPoolFactory);

    const priAddress = (await factory.pools(1)).poolAddress;
    console.log("Priority pool address:", priAddress);
    const priPool: PriorityPool = new PriorityPool__factory(dev_account).attach(
      priAddress
    );

    const priLPAddress = await priPool.currentLPAddress();

    const priceIndex = await priPool.priceIndex(priLPAddress);
    console.log("Price index of lp token: ", priceIndex.toString());

    const tx = await center.unstakeLiquidity(
      1,
      priLPAddress,
      parseUnits("10", 6)
    );

    console.log("Tx details: ", await tx.wait());
  }
);

task("checkPri", "Check priority pool status").setAction(
  async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();
    const priorityPoolList = readPriorityPoolList();

    const center: PolicyCenter = new PolicyCenter__factory(dev_account).attach(
      addressList[network.name].PolicyCenter
    );

    const factory: PriorityPoolFactory = new PriorityPoolFactory__factory(
      dev_account
    ).attach(addressList[network.name].PriorityPoolFactory);

    const priAddress = (await factory.pools(2)).poolAddress;
    console.log("Priority pool address:", priAddress);
    const priPool: PriorityPool = new PriorityPool__factory(dev_account).attach(
      priAddress
    );

    const priLPAddress = await priPool.currentLPAddress();
    console.log("current lp address: ", priLPAddress);
  }
);

task("getAllPriorityPool", "Get all priority pool list").setAction(
  async (_, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const factory: PriorityPoolFactory = new PriorityPoolFactory__factory(
      dev_account
    ).attach(addressList[network.name].PriorityPoolFactory);

    const poolList = await factory.getPoolAddressList();
    console.log("Total amount: ", poolList.length);

    console.log("Address list", poolList);
  }
);

task("getPoolInfo", "Get priority pool info")
  .addParam("id", "Pool id", null, types.string)
  .setAction(async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const factory: PriorityPoolFactory = new PriorityPoolFactory__factory(
      dev_account
    ).attach(addressList[network.name].PriorityPoolFactory);

    const poolInfo = await factory.pools(taskArgs.id);
    console.log("Pool name: ", poolInfo.protocolName);
    console.log("Pool native token: ", poolInfo.protocolToken);
    console.log("Pool address: ", poolInfo.poolAddress);
  });

task("activeCovered", "Get priority pool active covered")
  .addParam("id", "Pool id", null, types.string)
  .setAction(async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const factory: PriorityPoolFactory = new PriorityPoolFactory__factory(
      dev_account
    ).attach(addressList[network.name].PriorityPoolFactory);

    const poolAddress = (await factory.pools(taskArgs.id)).poolAddress;

    const pool: PriorityPool = new PriorityPool__factory(dev_account).attach(
      poolAddress
    );
    const covered = await pool.activeCovered();
    console.log("Active covered: ", formatUnits(covered, 6));

    const ratio = await pool.dynamicPremiumRatio(parseUnits("1000000", 6));
    console.log("Dynamic premium ratio: ", ratio.toString());

    const protectionPool: ProtectionPool = new ProtectionPool__factory(
      dev_account
    ).attach(addressList[network.name].ProtectionPool);
    const totalCovered = await protectionPool.getTotalCovered();
    console.log("Total covered: ", totalCovered.toString());
  });

task("dynamicPremium", "Get priority pool active covered")
  .addParam("id", "Pool id", null, types.string)
  .setAction(async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const factory: PriorityPoolFactory = new PriorityPoolFactory__factory(
      dev_account
    ).attach(addressList[network.name].PriorityPoolFactory);

    const poolAddress = (await factory.pools(taskArgs.id)).poolAddress;

    const pool: PriorityPool = new PriorityPool__factory(dev_account).attach(
      poolAddress
    );
    const ratio = await pool.dynamicPremiumRatio(parseUnits("10", 6));
    console.log(ratio.toString());

    const dynamicCounter = await factory.dynamicPoolCounter();
    console.log(dynamicCounter.toString());
  });
