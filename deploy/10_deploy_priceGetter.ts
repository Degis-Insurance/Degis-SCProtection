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

  if (network.name == "avax" || network.name == "avaxTest") {
    const proxyOptions: ProxyOptions = {
      proxyContract: "OpenZeppelinTransparentProxy",
      viaAdminContract: { name: "ProxyAdmin", artifact: "ProxyAdmin" },
      execute: {
        init: {
          methodName: "initialize",
          args: [],
        },
      },
    };

    // PriceGetter contract artifact
    const priceGetter = await deploy("PriceGetter", {
      contract: "PriceGetter",
      from: deployer,
      proxy: proxyOptions,
      args: [],
      log: true,
    });
    addressList[network.name].PriceGetter = priceGetter.address;

    impList[network.name].PriceGetter = priceGetter.implementation;

    console.log("PriceGetter deployed to address: ", priceGetter.address, "\n");

    // Store the address list after deployment
    storeAddressList(addressList);
    storeImpList(impList);
  }
};

func.tags = ["PriceGetter"];
export default func;
