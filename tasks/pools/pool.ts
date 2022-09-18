import { task, types } from "hardhat/config";
import "@nomiclabs/hardhat-ethers";

import {
  readAddressList,
  readPriorityPoolList,
  storePriorityPoolList,
} from "../../scripts/contractAddress";
import {
  MockSHIELD,
  MockSHIELD__factory,
  MockVeDEG,
  MockVeDEG__factory,
  OnboardProposal,
  OnboardProposal__factory,
  PolicyCenter,
  PolicyCenter__factory,
  PriorityPool,
  PriorityPoolDeployer,
  PriorityPoolDeployer__factory,
  PriorityPoolFactory,
  PriorityPoolFactory__factory,
  PriorityPool__factory,
  ProtectionPool,
  ProtectionPool__factory,
} from "../../typechain-types";
import { formatUnits, parseUnits } from "ethers/lib/utils";

// npx hardhat deployPriorityPool --network fuji --name TraderJoe --token 0x2C563651419A72e721D83151713428D467f1Ce22 --capacity 2000 --premium 200
// npx hardhat deployPriorityPool --network fuji --name GMX --token 0x10C9F09503048B0b93B12b316C4eb93324a79fdf --capacity 2000 --premium 200
// npx hardhat deployPriorityPool --network fuji --name PTP --token 0x1A0F76C19F9A9301A3cDE8532f72ce703FE58856 --capacity 2000 --premium 250
// npx hardhat deployPriorityPool --network fuji --name IME --token 0xe6b592f03Cc0447E61004C5437c3579b590B6Efb --capacity 2000 --premium 250
// npx hardhat deployPriorityPool --network fuji --name XAVA --token 0x8BfA09Bc7778f98505160C08d1E2D519B4c6137e --capacity 2500 --premium 200

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

task("provideLiquidity", "Provide liquidity to protection pool")
  .addParam("amount", "Amount to provide", null, types.string)
  .setAction(async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const center: PolicyCenter = new PolicyCenter__factory(dev_account).attach(
      addressList[network.name].PolicyCenter
    );

    const shield: MockSHIELD = new MockSHIELD__factory(dev_account).attach(
      addressList[network.name].MockShield
    );

    if (
      (await shield.allowance(dev_account.address, center.address)) <
      parseUnits("100000")
    ) {
      const tx = await shield.approve(
        center.address,
        parseUnits("100000000000")
      );
      console.log("Tx details: ", await tx.wait());
    }

    const tx = await center.provideLiquidity(parseUnits(taskArgs.amount, 6));
    console.log("Tx details: ", await tx.wait());
  });

task("stakeLiquidity", "Stake liquidity to priority pool")
  .addParam("id", "Pool id", null, types.string)
  .addParam("amount", "Amount to stake", null, types.string)
  .setAction(async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const center: PolicyCenter = new PolicyCenter__factory(dev_account).attach(
      addressList[network.name].PolicyCenter
    );

    const tx = await center.stakeLiquidity(
      taskArgs.id,
      parseUnits(taskArgs.amount, 6)
    );
    console.log("Tx details: ", await tx.wait());
  });

task("unstakeLiquidity", "UnStake liquidity from priority pool")
  .addParam("id", "Pool id", null, types.string)
  .addParam("gen", "Generation of PRI-LP token", null, types.string)
  .addParam("amount", "Amount to unstake", null, types.string)
  .setAction(async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const center: PolicyCenter = new PolicyCenter__factory(dev_account).attach(
      addressList[network.name].PolicyCenter
    );

    const factory: PriorityPoolFactory = new PriorityPoolFactory__factory(
      dev_account
    ).attach(addressList[network.name].PriorityPoolFactory);

    const priAddress = (await factory.pools(taskArgs.id)).poolAddress;
    console.log("Priority pool address:", priAddress);
    const priPool: PriorityPool = new PriorityPool__factory(dev_account).attach(
      priAddress
    );

    const priLPAddress = await priPool.lpTokenAddress(taskArgs.gen);

    const priceIndex = await priPool.priceIndex(priLPAddress);
    console.log("Price index of lp token: ", priceIndex.toString());

    const tx = await center.unstakeLiquidity(
      taskArgs.id,
      priLPAddress,
      parseUnits(taskArgs.amount, 6)
    );

    console.log("Tx details: ", await tx.wait());
  });

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

    const coverIndex = await pool.coverIndex();
    console.log("Cover index: ", coverIndex.toString());

    const protectionPool: ProtectionPool = new ProtectionPool__factory(
      dev_account
    ).attach(addressList[network.name].ProtectionPool);
    const totalCovered = await protectionPool.getTotalCovered();
    console.log("Total covered: ", totalCovered.toString());

    const totalActiveCovered = await protectionPool.getTotalActiveCovered();
    console.log("Total covered: ", totalActiveCovered.toString());
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

    const protectionPool: ProtectionPool = new ProtectionPool__factory(
      dev_account
    ).attach(addressList[network.name].ProtectionPool);

    const stakedSupply = await protectionPool.stakedSupply();
    console.log("Staked supply: ", stakedSupply.toString());

    const poolAddress = (await factory.pools(taskArgs.id)).poolAddress;
    console.log("pool address:", poolAddress);

    const pool: PriorityPool = new PriorityPool__factory(dev_account).attach(
      poolAddress
    );
    const ratio = await pool.dynamicPremiumRatio(0);
    console.log(ratio.toString());

    const dynamicCounter = await factory.dynamicPoolCounter();
    console.log("Dynamic pool counter:", dynamicCounter.toString());

    const minReq = await pool.minAssetRequirement();
    console.log("Min requirement: ", minReq.toString());
  });

task("updateIndexCut", "Buy a cover").setAction(async (_, hre) => {
  const { network } = hre;

  // Signers
  const [dev_account] = await hre.ethers.getSigners();
  console.log("The default signer is: ", dev_account.address);

  const addressList = readAddressList();

  const protectionPool: ProtectionPool = new ProtectionPool__factory(
    dev_account
  ).attach(addressList[network.name].ProtectionPool);

  const tx = await protectionPool.updateIndexCut();

  console.log("Tx details", await tx.wait());
});
