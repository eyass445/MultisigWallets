// This script can be used to deploy the "Storage" contract using Web3 library.
// Please make sure to compile "./contracts/1_Storage.sol" file before running this script.
// And use Right click -> "Run" from context menu of the file to run the script. Shortcut: Ctrl+Shift+S

import { deploy } from './web3-lib'

(async () => {
    try {
        const result = await deploy('UniswapV3NFTPoolCreator', [["0x880730f4f1b7ab045ea428c238Ea4a182f9Ac558","0x35bD3F9cF97ffb44681805166fE9F7B793c543b8"], 2])
        console.log(`address: ${result.address}`)
    } catch (e) {
        console.log(e.message)
    }
})()