# Smart Contracts
- ERC20:     Token
- Solidity:  ^0.8.0
- Tool:      hardhat-waffle ethereum-waffle
- UnitTest:  TypeScript + mocha + chai
- Deploy:    hardhat + alchemyapi

# Local Development

The following assumes the use of `node@>=10`.

## Install Dependencies

`yarn`

## Compile Contracts

`yarn compile`

## Run Tests

`cp .env.example .env`
`yarn test`


## Deploy to Testnet

```
export ROPSTEN_PRIVATE_KEY=<Your private key>
npx hardhat run scripts/deploy.ts --network ropsten
```
or
`yarn deploy`