import { cookieStorage, createConfig, createStorage, http, noopStorage } from 'wagmi'
import { mainnet, sepolia, unichain } from 'wagmi/chains'
import { baseAccount, injected, walletConnect } from 'wagmi/connectors'

export function getConfig() {
  return createConfig({
    chains: [unichain, mainnet, sepolia],
    connectors: [
      injected(),
      baseAccount(),
      walletConnect({ projectId: process.env.NEXT_PUBLIC_WC_PROJECT_ID! }),
    ],
    storage: createStorage({
      storage: typeof window !== 'undefined' ? cookieStorage : noopStorage,
    }),
    ssr: true,
    transports: {
      [unichain.id]: http(),
      [mainnet.id]: http(),
      [sepolia.id]: http(),
    },
  })
}

declare module 'wagmi' {
  interface Register {
    config: ReturnType<typeof getConfig>
  }
}
