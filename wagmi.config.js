import { defineConfig } from '@wagmi/cli'
import { hardhat } from '@wagmi/cli/plugins'
 
export default defineConfig({
  plugins: [
    hardhat({
      include: [
        // the following patterns are included by default
        '*.json',
      ],
      project: '../BinBins',
    }),
  ],
})