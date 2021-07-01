
const Web3 = require('web3');
const BEP20 = artifacts.require("BEP20");
const Offer = artifacts.require("Offer");

contract('test', ([alice, bob, carol, dev, minter]) => {
    it('t', async () => {
        let web3 = new Web3("https://data-seed-prebsc-1-s1.binance.org:8545");

        let block = await web3.eth.getBlockNumber();
        console.log(block);


        let test = new web3.eth.Contract(Offer.abi, "0x4db7B3535A1721493fD2c2edBe2cc679DEAFc694");

        let res = await test.getPastEvents("allEvents", {
            fromBlock: "10124000",
            toBlock: "10124300"
        });
        console.log(res);



        /*
        let res = await web3.eth.getTransaction("0x83ea1c1112cbd2914d243a9d746ff22b745edc8f457d929536954938ee299c8a");
        console.log(res);

         */
    });
});