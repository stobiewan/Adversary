# README #

Instructions to get running from truffle box starting point at http://truffleframework.com/boxes/truffle-vue


The port for development export in truffle.js has been set to 7545 which is the default for Ganache (which has improved and replaced testRPC).


In Ganache set gas limit to at least 10000000 in settings->chain, may not be necessary. Migrations on development network currently deploy the example truffle box contract, the real dapp contract, and fake dai which can be used for testing. After migrating it makes txs to set dai address in adversary contract and give some dai to your first addresses, you can use any seed.


To run tests which use async you need:
Node ≥ 7.6, confirm by entering node -v in command line
npm ≥ 4, confirm by entering npm -v in command line
plus latest truffle and Ganache, 4.18 and 1.1.0?


commands to complie, migrate and test smart contracts:  # faster not to always use reset but safer
truffle compile --reset
truffle migrate --network development --reset
npm run test/truffle


Only stuff which matters at the moment is in contracts/* (except for users.sol), migrations/* and test/truffle/* . If it's easier everything else can be deleted, or start fresh with another repo, truffle init and bring that stuff in.
