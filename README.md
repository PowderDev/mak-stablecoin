# Mak Stablecoin

What is this project consist of?

- Mak Stablecoin
  - Fully tested collateralized stablecoin.
  - Takes LINK (potentially any ERC20) as collateral and mints MSC
  - Uses Chainlink price feeds to determine the collateralization ratio
- Mak NFT
  - ERC721 NFT contract
  - Uses Chainlink VRF to generate random numbers for the NFTs
  - Can be bought only with MSC
- Blockchain Indexer
  - Indexes all the events from the Mak Stablecoin and Mak NFT contracts (and potentially any other events)
  - Uses Radis as a db and a pubsub system
- Frontend
- Backend

[To see this project in action](https://drive.google.com/file/d/1mola77K-14MwQIjGo3HHw2HtfUNeMFnl/view?usp=sharing)

![screenshot](https://i.postimg.cc/fR7GDKq5/Screenshot-2024-04-11-133522.png)
