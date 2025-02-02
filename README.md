- `Events : Events are log in EVM when we call the events it store the transaction log `
- pickWinner(): Get the random number and the random number pick the players who win the lottery , be automatic called
- i_interval = The duration of the lottery rounds in second's
- `!(bang)` = This mean not qual
- s_winner = checking who is the winner

When we Write function it's be CEI means = Check , Effects , interactions
checks => require, conditionals
Effects => Internal contract Updates
Interactions => External contract interaction

- @note - This is the function that the Chainlink Keeper nodes call
- they look for `upkeepNeeded` to return True.
- the following should be true for this to return true:
- 1.  The time interval has passed between raffle runs.
- 2.  The lottery is open.
- 3.  The contract has ETH.
- 4.  There are players registered.
- 5.  Implicitly, your subscription is funded with LINK.



- 1.  The time interval has passed between raffle runs.
- 2.  The lottery is open.
- 3.  The contract has ETH.
- 4.  There are players registered.

- 5.  Implicitly, your subscription is funded with LINK.
- `vm.wrap = set the time stamp `
- `vm.roll = change the block number `
- `Fuzzing Test ` - Fuzzing in Solidity is a testing technique used to find vulnerabilities and bugs in smart contracts by providing random or unexpected inputs to the contract's functions. The goal is to identify edge cases and potential security issues that might not be discovered through regular testing methods.


`Fuzzing` is a powerful technique to ensure the robustness and security of your smart contracts by uncovering unexpected behaviors and vulnerabilities.
The `hoax` cheatcode is a powerful testing tool that serves two key purposes in one call:

Funds an address with ETH
Sets up transaction impersonation `(prank)` for that address

* 1. `Unit tests` - Basic tests that check the functionality of individual functions or small units of code.
* 2. `Integration` tests - We test our deployment scripts and other components of our contracts 
* 3. `Forked tests` - Pseudo staging environments
* 4. `Staging tests` - We run tests on a mainnet/testnet fork to ensure our contracts are working as expected.
`stateful fuzzing`  
`forge test --debug` The tool to debug the test file 
