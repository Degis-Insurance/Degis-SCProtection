import { task, types } from "hardhat/config";
import { readAddressList } from "../../scripts/contractAddress";
import {
  DexPriceGetter,
  DexPriceGetterV2,
  DexPriceGetterV2__factory,
  DexPriceGetter__factory,
  PolicyCenter,
  PolicyCenter__factory,
} from "../../typechain-types";

task("setOracleType")
  .addParam("address", "Token address", null, types.string)
  .addOptionalParam("type", "Oracle type", 1, types.int)
  .setAction(async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const policyCenter: PolicyCenter = new PolicyCenter__factory(
      dev_account
    ).attach(addressList[network.name].PolicyCenter);

    const tx = await policyCenter.setOracleType(
      taskArgs.address,
      taskArgs.type
    );
    console.log("Tx details", await tx.wait());
  });

task("getOracleType")
  .addParam("address", "Token address", null, types.string)
  .setAction(async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const policyCenter: PolicyCenter = new PolicyCenter__factory(
      dev_account
    ).attach(addressList[network.name].PolicyCenter);

    const type = await policyCenter.oracleType(taskArgs.address);
    console.log(
      "Current oracle type",
      type.toString() == "0" ? "ChainLink" : "DEX"
    );
  });

// Arb Joe V2.1 Router: 0xb4315e873dBcf96Ffd0acd8EA43f689D8c20fB30

task("setExchangeByToken")
  .addParam("token")
  .addParam("exchange")
  .setAction(async (taskArgs, hre) => {
    const { network } = hre;

    // Signers
    const [dev_account] = await hre.ethers.getSigners();
    console.log("The default signer is: ", dev_account.address);

    const addressList = readAddressList();

    const policyCenter: PolicyCenter = new PolicyCenter__factory(
      dev_account
    ).attach(addressList[network.name].PolicyCenter);

    const currentExchange = await policyCenter.exchangeByToken(taskArgs.token);
    console.log("Current exchange", currentExchange);

    const tx = await policyCenter.setExchangeByToken(
      taskArgs.token,
      taskArgs.exchange
    );
    console.log("Tx details", await tx.wait());
  });

task("dexGetterV2").setAction(async (taskArgs, hre) => {
  const { network } = hre;

  // Signers
  const [dev_account] = await hre.ethers.getSigners();
  console.log("The default signer is: ", dev_account.address);

  const addressList = readAddressList();

  const dexGetterV2: DexPriceGetterV2 = new DexPriceGetterV2__factory(
    dev_account
  ).attach(addressList[network.name].DexPriceGetterV2);

  // const token = "0x371c7ec6D8039ff7933a2AA28EB827Ffe1F52f07";
  const token = "0x912CE59144191C1204E64559FE8253a0e49E6548";
  // const token = "0x18c11FD286C5EC11c3b683Caa813B77f5163A122";

  // const price = await dexGetterV2.samplePriceFromUniV3(token);
  // console.log("Price", hre.ethers.utils.formatEther(price));
  // console.log("Price", price.toString());

  const lbfeed = await dexGetterV2.lbPriceFeeds(token);
  console.log("lbfeed", lbfeed.lastCumulativeId.toString());
  console.log("lbfeed", lbfeed.lastTimestamp.toString());
  console.log("lbfeed", hre.ethers.utils.formatEther(lbfeed.price));

  // const tx = await dexGetterV2.samplePriceFromLB(token);
  // console.log("Tx details", await tx.wait());
});

// name: WOM
// pair: 0x0e1e13846e3320b8a471b72080b8cde86cdee3c2
// decimals: 6
// interval: 60 * 60 = 3600
task("addDexPriceFeedUSDT")
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

    const priceFeed = await dexGetter.priceFeeds(taskArgs.name);
    console.log("Current price feed", priceFeed);

    // const tx = await dexGetter.addUSDTPair(
    //   taskArgs.name,
    //   taskArgs.pair,
    //   taskArgs.decimals,
    //   taskArgs.interval
    // );
    // console.log("Tx details:", await tx.wait());
  });
