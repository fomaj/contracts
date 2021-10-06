import { PolyjuiceWallet, PolyjuiceJsonRpcProvider } from '@polyjuice-provider/ethers';
import { NERVOS_PROVIDER_URL, CORE_PRIVATE_KEY, ORACLE_UPDATER_PRIVATE_KEY } from './config';

const nervosProviderConfig = {
    web3Url: NERVOS_PROVIDER_URL
};

export const rpc = new PolyjuiceJsonRpcProvider(nervosProviderConfig, nervosProviderConfig.web3Url);

//@ts-ignore
export const deployer = new PolyjuiceWallet(CORE_PRIVATE_KEY as string, nervosProviderConfig, rpc);
//@ts-ignore
export const oracleDeployer = new PolyjuiceWallet(ORACLE_UPDATER_PRIVATE_KEY as string, nervosProviderConfig, rpc);