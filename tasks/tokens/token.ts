import { task, types } from "hardhat/config";
import "@nomiclabs/hardhat-ethers";

import { readAddressList } from "../../scripts/contractAddress";
import {
  MockDEG,
  MockDEG__factory,
  PolicyCenter,
  PolicyCenter__factory,
  ProtectionPool,
  ProtectionPool__factory,
  MockSHIELD,
  MockSHIELD__factory,
  MockUSDC,
  MockUSDC__factory,
  CoverRightToken,
  CoverRightToken__factory,
  CoverRightTokenFactory,
  CoverRightTokenFactory__factory,
  MockVeDEG,
  MockVeDEG__factory,
  MockERC20,
  MockERC20__factory,
  IncidentReport,
  IncidentReport__factory,
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

  const tx = await deg.mintDegis(dev_account.address, parseUnits("50000"));
  console.log("tx details", await tx.wait());

  const balance = await deg.balanceOf(dev_account.address);
  console.log(formatUnits(balance, 18));
});

task("mintMockERC20", "Mint mock erc20 tokens").setAction(async (_, hre) => {
  const { network } = hre;

  // Signers
  const [dev_account] = await hre.ethers.getSigners();
  console.log("The default signer is: ", dev_account.address);

  const addressList = readAddressList();

  const token: MockERC20 = new MockERC20__factory(dev_account).attach(
    addressList[network.name].TestProject2
  );

  const to = dev_account.address;

  const tx = await token.mint(to, parseUnits("1000000"));
  console.log("tx details", await tx.wait());

  await token.approve(
    addressList[network.name].PolicyCenter,
    parseUnits("10000000")
  );

  const balance = await token.balanceOf(dev_account.address);
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

  const tx = await shield.mint(dev_account.address, parseUnits("10000", 6));
  console.log("tx details", await tx.wait());

  const balance = await shield.balanceOf(dev_account.address);
  console.log(formatUnits(balance, 6));
});

task("mintVeDEG", "Mint veDEG tokens").setAction(async (_, hre) => {
  const { network } = hre;

  // Signers
  const [dev_account] = await hre.ethers.getSigners();
  console.log("The default signer is: ", dev_account.address);

  const addressList = readAddressList();

  const veDEG: MockVeDEG = new MockVeDEG__factory(dev_account).attach(
    addressList[network.name].MockVeDEG
  );

  const tx = await veDEG.mint(dev_account.address, parseUnits("4000000", 18));
  console.log("tx details", await tx.wait());

  const balance = await veDEG.balanceOf(dev_account.address);
  console.log(formatUnits(balance, 6));
});

task("mintMockUSD", "Mint mockUSD for mockExchange").setAction(
  async (_, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const usd: MockUSDC = new MockUSDC__factory(dev_account).attach(
      addressList[network.name].MockUSDT
      // "0x23d0cddC1Ea9Fcc5CA9ec6b5fC77E304bCe8d4c3"
    );

    const address = "0x32eB34d060c12aD0491d260c436d30e5fB13a8Cd";

    const tx = await usd.mint(address, parseUnits("1000000000", 6));
    console.log("tx details", await tx.wait());

    const balance = await usd.balanceOf(address);
    console.log("USDC balance of mock exchange:", formatUnits(balance, 6));
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
    addressList[network.name].MockUSDC
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
  ).attach("0xc4F8Ac8B98b2f1b6C86467d2c9992C882Bdf3BFa");

  const gen = await crToken.generation();
  console.log("gen", gen.toString());

  const expiry = await crToken.expiry();
  console.log("expiry", expiry.toString());

  const incidentReport = await crToken.incidentReport();
  console.log("Incident report in cr: ", incidentReport);
  const inci: IncidentReport = new IncidentReport__factory(dev_account).attach(
    incidentReport
  );

  const poolReportAmount = await inci.getPoolReportsAmount(2);
  console.log("Report amount: ", poolReportAmount.toString());

  const poolReports = await inci.poolReports(2, 1);
  console.log("Report id: ", poolReports.toString());

  const claimable = await crToken.getClaimableOf(dev_account.address);
  console.log("Claimable: ", claimable.toString());

  const excluded = await crToken.getExcludedCoverageOf(dev_account.address);
  console.log("Excluded: ", excluded.toString());
});
