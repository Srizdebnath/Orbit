import { http, createConfig } from 'wagmi'
import { base, optimism, mode } from 'wagmi/chains'
import { injected } from 'wagmi/connectors'

export const config = createConfig({
  chains: [base, optimism, mode],
  connectors: [
    injected(), 
  ],
  transports: {
    [base.id]: http(),
    [optimism.id]: http(),
    [mode.id]: http(),
  },
})