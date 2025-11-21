import { defineWalletSetup } from '@synthetixio/synpress';
import { MetaMask } from '@synthetixio/synpress/playwright';
import dotenv from 'dotenv';

dotenv.config();

const SEED_PHRASE = (process.env.SEED_PHRASE || 'brick jeans notice danger fatigue judge turtle retire miss hold office sauce').trim();
const PASSWORD = (process.env.METAMASK_PASSWORD || 'Tester@1234').trim();

const setup = defineWalletSetup(PASSWORD, async (context, walletPage) => {
  const metamask = new MetaMask(context, walletPage, PASSWORD);
  await metamask.importWallet(SEED_PHRASE);
});

export default setup;
export const walletPassword = PASSWORD;
