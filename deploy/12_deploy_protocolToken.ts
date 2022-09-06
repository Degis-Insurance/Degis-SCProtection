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

  const name = "TestToken1";
  const symbol = "TT";
  const decimal = 18;

  // PriceGetter contract artifact
  const mockERC20 = await deploy("MockERC20", {
    contract: "MockERC20",
    from: deployer,
    args: [name, symbol, decimal],
    log: true,
  });
  addressList[network.name].MockERC20 = mockERC20.address;

  console.log("A mock erc20 deployed to address: ", mockERC20.address, "\n");

  // Store the address list after deployment
  storeAddressList(addressList);
};

func.tags = ["MockERC20"];
export default func;
