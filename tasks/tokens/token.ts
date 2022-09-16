import { task, types } from "hardhat/config";
import "@nomiclabs/hardhat-ethers";

import { readAddressList } from "../../scripts/contractAddress";
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
  MockERC20,
  MockERC20__factory,
  MockUSDC,
  MockUSDC__factory,
  CoverRightToken,
  CoverRightToken__factory,
  CoverRightTokenFactory,
  CoverRightTokenFactory__factory,
} from "../../typechain-types";
import { formatUnits, parseUnits } from "ethers/lib/utils";

task("mintDegis", "Mint degis tokens").setAction(async (_, hre) => {
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

  const balance = await deg.balanceOf(dev_account.address);
  console.log(formatUnits(balance, 18));
});

task("mintShield", "Mint shield tokens").setAction(async (_, hre) => {
  const { network } = hre;

  // Signers
  const [dev_account] = await hre.ethers.getSigners();
  console.log("The default signer is: ", dev_account.address);

  const addressList = readAddressList();

  const shield: MockSHIELD = new MockSHIELD__factory(dev_account).attach(
    addressList[network.name].MockShield
  );

  const tx = await shield.mint(dev_account.address, parseUnits("1000", 6));
  console.log("tx details", await tx.wait());

  const balance = await shield.balanceOf(dev_account.address);
  console.log(formatUnits(balance, 6));
});

task("mintMockUSD").setAction(async (_, hre) => {
  const { network } = hre;

  // Signers
  const [dev_account] = await hre.ethers.getSigners();
  console.log("The default signer is: ", dev_account.address);

  const addressList = readAddressList();

  const usd: MockUSDC = new MockUSDC__factory(dev_account).attach(
    addressList[network.name].MockUSDC
  );

  const tx = await usd.mint(
    addressList[network.name].MockExchange,
    parseUnits("1000000000", 6)
  );
  console.log("tx details", await tx.wait());

  const balance = await usd.balanceOf(addressList[network.name].MockExchange);
  console.log("USDC balance:", formatUnits(balance, 6));
});

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

task("getCRToken", "Get cr token address").setAction(async (_, hre) => {
  const { network } = hre;

  // Signers
  const [dev_account] = await hre.ethers.getSigners();
  console.log("The default signer is: ", dev_account.address);

  const addressList = readAddressList();

  const crFactory: CoverRightTokenFactory = new CoverRightTokenFactory__factory(
    dev_account
  ).attach(addressList[network.name].CoverRightTokenFactory);

  const salt = hre.ethers.utils.solidityKeccak256(
    ["uint256", "uint256", "uint256"],
    [1, 1664553599, 1]
  );

  const address = await crFactory.saltToAddress(salt);
  console.log("cr address:", address);

  const crToken: CoverRightToken = new CoverRightToken__factory(
    dev_account
  ).attach("0xC8845faF685cD8CB637BcB2067675C364b67820d");

  const gen = await crToken.generation();
  console.log("gen", gen.toString());

  const expiry = await crToken.expiry();
  console.log("expiry", expiry.toString());
});
