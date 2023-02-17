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
    network.name == "avaxNew"
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
    const dexPriceGetter = await deploy("DexPriceGetter", {
      contract: "DexPriceGetter",
      from: deployer,
      proxy: proxyOptions,
      args: [],
      log: true,
    });
    addressList[network.name].DexPriceGetter = dexPriceGetter.address;

    impList[network.name].DexPriceGetter = dexPriceGetter.implementation;

    console.log(
      "PriceGetter deployed to address: ",
      dexPriceGetter.address,
      "\n"
    );

    // Store the address list after deployment
    storeAddressList(addressList);
    storeImpList(impList);
  }
};

func.tags = ["DexPriceGetter"];
export default func;
