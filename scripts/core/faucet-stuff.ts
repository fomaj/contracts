import { AddressTranslator } from "nervos-godwoken-integration";
import { FMJFaucet__factory, FMJToken__factory } from "../../typechain";
import { FAUCET_ADDRESS, TOKEN_ADDRESS } from "../config";
import { deployer } from "../provider";

const main = async () => {
    const address = new AddressTranslator().ethAddressToGodwokenShortAddress(deployer.address)
    const tokenContract = FMJToken__factory.connect(TOKEN_ADDRESS as string, deployer);
   
    let balance = await tokenContract.balanceOf(address);
    console.log("Balance faucet: ", balance.toNumber());

    const faucetContract = FMJFaucet__factory.connect(FAUCET_ADDRESS as string, deployer);
    console.log("Requesting fund from faucet");
    await (await faucetContract.requestToken({
      gasPrice: 0,
      gasLimit: 6_000_000
    })).wait();

    balance = await tokenContract.balanceOf(address);
    console.log("Balance after: ", balance.toNumber());
    
}

main()
.then(() => process.exit(0))
.catch(error => {
  console.error(error);
  process.exit(1);
});