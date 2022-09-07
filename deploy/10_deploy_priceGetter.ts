import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

import { readAddressList, storeAddressList } from "../scripts/contractAddress";

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

  if (network.name == "avax") {
    // PriceGetter contract artifact
    const priceGetter = await deploy("PriceGetter", {
      contract: "PriceGetter",
      from: deployer,
      args: [],
      log: true,
    });
    addressList[network.name].PriceGetter = priceGetter.address;

    console.log("PriceGetter deployed to address: ", priceGetter.address, "\n");

    // Store the address list after deployment
    storeAddressList(addressList);
  }
};

func.tags = ["PriceGetter"];
export default func;
