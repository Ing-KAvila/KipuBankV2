
**KipuBank** is a multi-token custody contract that allows users to:
Deposit and withdraw ETH or ERC-20 tokens.
Keep their funds in a personal vault.
Operate under secure limits defined in USD, thanks to Chainlink.

The **KipuBankV2** contract represents a significant evolution from the previous version. The improvements focus on security, scalability, interoperability, and administrative control, with the following key changes:
   - Support for ERC-20 tokens is expanded, allowing deposits and withdrawals in multiple assets.
   - SafeERC20 is used for secure transfers, avoiding common errors with non-standard tokens.
   - Limits in ETH are replaced by limits in USD, using the Chainlink ETH/USD price feed.
   - ReentrancyGuard and Pausable are integrated to protect against attacks and allow for operational pauses.
   - Custom modifiers are applied to validate limits before executing transfers.
   - Ownable is added to allow owner-exclusive functions such as token recovery and pause control.
   - recoverToken() is implemented to mitigate accidental sending errors.

**Key design decisions**
   - Use of Chainlink: enables dynamic limits based on USD, which are more intuitive for users.
   - Modularity with interfaces and libraries: facilitates auditing, maintenance, and scalability.
   - Well-defined events: clear traceability in block explorers.

Trade-offs considered:
   - Simplified conversion for tokens: assumed to be 1:1 with USD for stable tokens, which is efficient but can be inaccurate for volatile tokens.
   - No array of tracked tokens included: avoids extra gas, but limits the total USD calculation if multiple tokens are used.
   - Use of call for ETH: more flexible than transfer, but requires explicit error handling.

This contract is ideal for platforms that handle multiple assets and DeFi applications that require dynamic limits.


**Main features**
1. Deposits
 Users can deposit:
 ETH directly (depositETH() or by sending ETH to the contract).
 ERC-20 tokens using depositToken(token, amount).


2. Withdrawals
 Users can withdraw:
 ETH with withdrawETH(amount).
 Tokens with withdrawToken(token, amount).

3. Limits in USD
 Two limits are defined:
 Global bank limit (bankCapUsd): maximum total allowed in the vault.
 Limit per transaction (withdrawalLimitUsd): maximum that can be withdrawn per operation.
 Chainlink ETH/USD is used to convert amounts to USD.
 For ERC-20 tokens, a 1:1 equivalence with USD is assumed (useful for stablecoins).

4. Security
 All sensitive functions use nonReentrant and whenNotPaused.
 Use ReentrancyGuard to prevent reentrancy attacks.
 Uses Pausable to stop operations in case of emergency.
 Uses Ownable so that the owner can:
      Pause/unpause the contract.
      Recover tokens sent by mistake.
 Limits are validated before executing transfers.
 Custom errors are used for clarity and gas savings.
SafeERC20 is used to avoid failures with non-standard tokens.

5. Events and traceability
 Issues Deposited and Withdrawn events for each operation.
 Allows tracking of total deposits per token and per user.

**Interaction instructions**
-  depositETH(): send ETH directly or call the function.
-  depositToken(token, amount): first approve the contract, then call.
-  withdrawETH(amount): withdraw ETH if it meets the limit and balance.
-  withdrawToken(token, amount): withdraw ERC-20 tokens.
-  recoverToken(token, to, amount): only the owner can recover funds.
-  pause() / unpause(): emergency control by the owner.


**Contract deployment instructions**

**1. Constructor parameters**
 When deploying the contract, you must provide:
 - address _ethUsdFeed: address of the Chainlink ETH/USD price feed.
-  Example in Sepolia: 0x694AA1769357215DE4FAC081bf1f309aDC325306
-  uint256 _bankCapUsd: total bank limit in USD (with 6 decimal places).
-  Example: 100000000 for $100,000.00
-  uint256 _withdrawalLimitUsd: limit per transaction in USD (with 6 decimal places).
-  Example: 5000000 for $5,000.00

*In Remix*
 - Copy the contract into Remix.
-  Select Solidity 0.8.30 compiler.
-  Make sure to import OpenZeppelin and Chainlink correctly.
-  Deploy the contract with the above parameters.


**2. Interaction with functions**
  - Deposit ETH
     function depositETH() public payable
     *In Remix:* select depositETH() and send ETH in the “Value” field.

  - Deposit ERC-20 tokens
     function depositToken(address token, uint256 amount) external
     Steps:
     Ensure that the user has approved the contract to move their tokens:
     IERC20(token).approve(address(KipuBank), amount);
     Call depositToken(token, amount).

  - Withdraw ETH
     function withdrawETH(uint256 amount) external
     Verify that the amount is within the USD limit and that the user has sufficient balance.
     Call the function and the contract will send ETH to the user.

  - Withdraw ERC-20 tokens
     function withdrawToken(address token, uint256 amount) external
     Verify that the token is not address(0) and that the user has a balance.
     Call the function and the contract will transfer the tokens.

  - Recover tokens (owner only)
     function recoverToken(address token, address to, uint256 amount) external onlyOwner
     Useful if someone accidentally sends tokens to the contract.
     The owner can recover ETH or tokens and send them to to.

  - Pause and resume the contract 
     function pause() external onlyOwner
     function unpause() external onlyOwner
     Pausing blocks deposits and withdrawals.
     Useful in case of emergency or maintenance.

**3. Queries and utilities**
  - View user balance
     vault[user][token]
     Queries a user's balance for a specific token.
  - View ETH/USD price
     getLatestEthUsdPrice()
     Returns the current price of ETH in USD (8 decimal places).
  - Convert amount to USD
     _convertToUsd(token, amount)
     Internal: converts any amount to USD based on the token type.

**4. Testing recommendations**
  - Test deposits and withdrawals with ETH and at least two ERC-20 tokens (one stable and one volatile).
  - Simulate scenarios where limits are exceeded to validate errors.
  - Verify that Deposited and Withdrawn events are issued correctly.
  - Test pausing and recovering tokens as owner.




**Location: Buenos Aires, Argentina. Date: October 25, 2025**
