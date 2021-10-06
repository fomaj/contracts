/* eslint-disable @typescript-eslint/camelcase */
import { BigNumber } from "ethers";
import { MockV3Aggregator__factory } from "../../typechain";
import { oracleDeployer as deployer } from '../provider';
import { aggregatorsDeployed } from "./aggregators";
import { getPriceUSD } from "./messari";

async function runDemo() {
  async function updateAllFeeds() {
    for (const aggregator of aggregatorsDeployed) {
      const market = await getPriceUSD(aggregator.baseName);
      const price = BigNumber.from(Math.round(market * Math.pow(10, aggregator.decimals)));

      const aggregatorContract = MockV3Aggregator__factory.connect(aggregator.address as string, deployer);

      console.log(`Updating ${aggregator.description} price...`);
      console.log(`Aggregator address: `, aggregator.address);

      try {
        console.log(price);
        await (await aggregatorContract.updateAnswer(price, {
          gasPrice: 0,
          gasLimit: 600_000
        })).wait();
        console.log(`Price of ${aggregator.description} updated to: "${price.toString()}"`);
      } catch (e) {
        console.error(e);
      }
    }
  }

  await updateAllFeeds();
}

(async () => {
  while (true) {
    console.log("Updating");
    await runDemo();
    console.log("Update finished. Waiting.");
    await new Promise(resolve => setTimeout(resolve, 1000 * 60 * 3));
  }
})();
