# SnapIt! contracts

You will find here the smart-contracts and associated tests for the `SnapIt!` product.

## Architectural overview

1. A factory is deployed by Snapshot (see [SpaceCollectionFactory](src/SpacecollectionFactory.sol)).
2. Space owners on Snapshot can decide to create their own `SpaceCollection` by calling the `deployProxy` method on the
   factory. This method expects `trustedBackend` (snapshot owned server) to sign the arguments. This ensures that the
   owner of a SpaceCollection is indeed the owner of the corresponding Space.
3. Users can collect NFTs for proposals in which they participate (including past ones!). To do this, they simply need
   to call the `mint` function on the corresponding `SpaceCollection`. They will also need to hand a signature (given by
   `trustedBackend`) to ensure they are minting a valid proposal.

## Fees

`mint`s are required to be paid in `WETH` on the Polygon chain. The space sets its own `mintPrice` and `mintSupply`. Two
different `fees` exist:

- The `proposerFee` : goes to the proposer of the proposal.
- The `snapshotFee`: goes to a multisig owned by Snapshot. This fee is computed _after_ the `proposerFee`.

## Devs

This repo uses `foundry` for tests. Interesting files are in `src`.
