# README #

Instructions to get running at http://truffleframework.com/boxes/truffle-vue


The port for development export in truffle.js has been set to 7545 which is the default for Ganache.


Deployment requires two additional actions, setOracleResponseGasPrice and setting the Dai contract address.


In Ganache set gas limit to at least 10000000 in settings->chain. Also set the following mneumonic so you get addresses which already have some fake dai after the migration:
film laundry blanket comfort steel modify author unveil pyramid resemble because mountain


To run test you need:
Node ≥ 7.6 confirm by entering node -v in command line
npm ≥ 4 confirm by entering npm -v in command line
plus latest truffle and Ganache, 4.18 and 1.1.0?


if you run into errors after compiling/ migrating and making changes use --reset ie
truffle compile --reset
truffle migrate --network development --reset
npm run test/truffle
