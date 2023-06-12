import { task, types } from "hardhat/config";
import { readAddressList } from "../../scripts/contractAddress";
import { PolicyCenter, PolicyCenter__factory } from "../../typechain-types";

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
