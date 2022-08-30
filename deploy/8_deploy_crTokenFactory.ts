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

  const policyCenterAddress = addressList[network.name].PolicyCenter;

  // CoverRightTokenFactory contract artifact
  const crTokenFactory = await deploy("CoverRightTokenFactory", {
    contract: "CoverRightTokenFactory",
    from: deployer,
    args: [policyCenterAddress],
    log: true,
  });
  addressList[network.name].CoverRightTokenFactory = crTokenFactory.address;

  console.log(
    "CoverRightTokenFactory deployed to address: ",
    crTokenFactory.address,
    "\n"
  );

  // Store the address list after deployment
  storeAddressList(addressList);
};

func.tags = ["CoverRightTokenFactory"];
export default func;
