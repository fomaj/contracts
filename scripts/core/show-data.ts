import { deployer, rpc } from "../provider";
import { FOMAJ_ADDRESS, CKB_USD_AGG, TOKEN_ADDRESS } from "../config";
import { FMJToken__factory, Fomaj__factory, MockV3Aggregator__factory } from "../../typechain";
import { AddressTranslator } from "nervos-godwoken-integration";

const main = async () => {
  const contract = Fomaj__factory.connect(FOMAJ_ADDRESS as string, deployer);
  console.log("------------------ Contract DATA------------------");
  console.log("Contract: ", FOMAJ_ADDRESS as string);
  const epoch = await contract.currentRoundNumber();
  console.log("Current round number: ", (epoch.toNumber()));
  const round = await contract.rounds(epoch);
  console.log("Round status", round.status)
  console.log("Round reward status", round.rewards.status)
  
  const polyAddress = new AddressTranslator().ethAddressToGodwokenShortAddress(deployer.address);
  console.log("Poly address: ", polyAddress);
  console.log("Staked Amount: ", (await contract.userInfo(polyAddress))[0].toNumber())
  
  const tokenContract = FMJToken__factory.connect(TOKEN_ADDRESS as string, deployer);
  console.log("------------------Token------------------");
  console.log("Token Contract: ", FOMAJ_ADDRESS as string);
  console.log("Token balance of contract", (await (await tokenContract.balanceOf(FOMAJ_ADDRESS as string)).toNumber()));

  console.log("------------------ORACLE DATA------------------");
  console.log("Chainlink Aggregator: ", CKB_USD_AGG as string);

  const aggregatorContract = MockV3Aggregator__factory.connect(CKB_USD_AGG as string, deployer);
  const latestOracleRound = await aggregatorContract.latestRoundData();

  console.log("Chainlink oracle price: ", latestOracleRound.answer.toString());
  console.log("Chainlink oracle roundId: ", latestOracleRound.roundId.toNumber());
};

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
