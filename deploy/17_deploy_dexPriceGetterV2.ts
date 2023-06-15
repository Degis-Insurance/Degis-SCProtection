import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction, ProxyOptions } from "hardhat-deploy/types";

import {
  readAddressList,
  readImpList,
  storeAddressList,
  storeImpList,
} from "../scripts/contractAddress";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, network } = hre;
  const { deploy } = deployments;

  network.name = network.name == "hardhat" ? "localhost" : network.name;

  const { deployer } = await getNamedAccounts();

  console.log("\n-----------------------------------------------------------");
  console.log("-----  Network:  ", network.name);
  console.log("-----  Deployer: ", deployer);
  console.log("-----------------------------------------------------------\n");

  // Read address list from local file
  const addressList = readAddressList();
  const impList = readImpList();

  const priceGetterAddress = addressList[network.name].PriceGetter;

  if (
    network.name == "avax" ||
    network.name == "avaxTest" ||
    network.name == "avaxNew" ||
    network.name == "arb"
  ) {
    const proxyOptions: ProxyOptions = {
      proxyContract: "OpenZeppelinTransparentProxy",
      viaAdminContract: { name: "ProxyAdmin", artifact: "ProxyAdmin" },
      execute: {
        init: {
          methodName: "initialize",
          args: [priceGetterAddress],
        },
      },
    };

    // PriceGetter contract artifact
    const dexPriceGetterV2 = await deploy("DexPriceGetterV2", {
      contract: "DexPriceGetterV2",
      from: deployer,
      proxy: proxyOptions,
      args: [],
      log: true,
    });
    addressList[network.name].DexPriceGetterV2 = dexPriceGetterV2.address;

    impList[network.name].DexPriceGetterV2 = dexPriceGetterV2.implementation;

    console.log(
      "PriceGetter deployed to address: ",
      dexPriceGetterV2.address,
      "\n"
    );

    // Store the address list after deployment
    storeAddressList(addressList);
    storeImpList(impList);
  }
};

func.tags = ["DexPriceGetterV2"];
export default func;
