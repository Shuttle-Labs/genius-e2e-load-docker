// @ts-nocheck
import { testWithSynpress } from '@synthetixio/synpress';
import { MetaMask, metaMaskFixtures } from '@synthetixio/synpress/playwright';

import demoSetup, { walletPassword } from '../wallet-setup/demo.setup.js';

import { DappLoginPage } from '../pages/dapp-login.page';
import { handleMetaMaskSignature } from '../utils/mm-signature.util';

const base = testWithSynpress(metaMaskFixtures(demoSetup));
const { expect } = base;

type Fixtures = {
    metamask: MetaMask;
    dappLogin: DappLoginPage;
    dapp: any;
};

const test = base.extend<Fixtures>({
    metamask: async ({ context, metamaskPage, extensionId }, use) => {
        const metamask = new MetaMask(context, metamaskPage, walletPassword, extensionId);
        await use(metamask);
    },

    dappLogin: async ({ page }, use) => {
        const dappLogin = new DappLoginPage(page);
        await use(dappLogin);
    },

    dapp: async ({ context, page, metamask, dappLogin }, use) => {
        await page.goto(process.env.BASE_URL || '');
        await page.reload();
        await expect(page).toHaveTitle(/Genius Pro/i);

        const dapp = await dappLogin.openDapp(context);

        await dappLogin.clickSignIn(dapp);
        await dappLogin.clickConnectWallet(dapp);
        await dappLogin.chooseMetaMask(dapp);

        await metamask.connectToDapp();
        await handleMetaMaskSignature(context);
        await handleMetaMaskSignature(context);
        await dappLogin.skip2FA(dapp);
        await dappLogin.verifyLoggedIn(dapp);

        await use(dapp);
    },
});

export { test, expect };
