import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import {config as dotenvConfig} from "dotenv";

try {
  dotenvConfig();
} catch (error) {
  console.error(
      "Loading .env file failed. Things will likely fail. You may want to copy .env.example and create a new one."
  );
}

const config: HardhatUserConfig = {
  solidity: "0.8.19",
};

export default config;
