import { Fomaj, Fomaj__factory } from "../../typechain";
import { BUFFER_SECONDS, FOMAJ_ADDRESS, INTERVAL_SECONDS } from "../config";
import { deployer } from "../provider";

const delay = parseInt(INTERVAL_SECONDS) * 1000 * 4;
const buffer = parseInt(BUFFER_SECONDS) * 1000;

const startExecution = async (contract: Fomaj) => {
  while(true) {
    try {
      console.log("Trying to execute.")
      const result = await (await contract.executeRound({
        gasPrice: 0,
        gasLimit: 6_000_000
      })).wait();
      console.log(`Round executed. Waiting ${delay / 1000} seconds.`);
      await new Promise((resolve) => setTimeout(resolve, delay));
    } catch (e) {
      console.log("Execution failed.");
    }
  }
};

const startGenesis = async (contract: Fomaj) => {
  try {
    console.log("Trying to start genesis round.");
    await (await contract.genesisStartRound(
      {
        gasPrice: 0,
        gasLimit: 6_000_000
      }
    )).wait();
    console.log("Genesis round started");
  } catch (error) {
    console.log("ERR: Failed.\n" + error);
  }
};

const start = async (contract: Fomaj) => {
  // start the genises block
  await startGenesis(contract);

  // wait for inteval
  console.log(`Waiting ${delay / 1000} seconds..`);
  await new Promise((resolve) => setTimeout(resolve, delay));

  // start executing
  await startExecution(contract);
};

const main = async () => {
    const contract = Fomaj__factory.connect(FOMAJ_ADDRESS as string, deployer);
    await start(contract);
  };
  
  main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });
  