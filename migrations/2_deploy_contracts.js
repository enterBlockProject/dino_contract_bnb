const Controller = artifacts.require('Controller');
const Dino = artifacts.require('Dino');
const Dino721 = artifacts.require('Dino721');
const Distributor = artifacts.require('Distributor');
const Mapper = artifacts.require('Mapper');
const Offer = artifacts.require('Offer');
const Staker = artifacts.require('Staker');
const Auction = artifacts.require('Auction');
const MockBEP20 = artifacts.require('MockBEP20');
const MockERC721 = artifacts.require('MockERC721');

module.exports = function (deployer) {
    let dinoInstance;
    let distributorInstance;
    deployer.deploy(Dino,
        "0x17142514BBb117aa14B80e081eC4423770cCB464",
        "0x17142514BBb117aa14B80e081eC4423770cCB464"
    ).then(function(instance) {
        dinoInstance = instance;
        return deployer.deploy(Controller, Dino.address);
    }).then(function(instance) {
        return deployer.deploy(Dino721, Dino.address);
    }).then(function(instance) {
        return deployer.deploy(Distributor,
            Dino.address,
            "10926500",
            "10512000",
            "156000000",
            "3");
    }).then(function(instance) {
        distributorInstance = instance;
        return deployer.deploy(Mapper, Dino.address);
    }).then(function(instance) {
        return deployer.deploy(Offer, Dino.address);
    }).then(function(instance) {
        return deployer.deploy(Staker, Dino.address);
    }).then(function(instance) {
        return deployer.deploy(MockBEP20, "USDT", "USDT", "1000000000000000000000000000000"); //test
    }).then(function(instance) {
        return deployer.deploy(MockERC721); //test
    }).then(function(instance) {
        return deployer.deploy(Auction, Dino.address);
    }).then(function(instance) {
        return dinoInstance.setController(Controller.address);
    }).then(function(instance) {
        return dinoInstance.setMapper(Mapper.address);
    }).then(function(instance) {
        return dinoInstance.setStaker(Staker.address);
    }).then(function(instance) {
        return dinoInstance.setOffer(Offer.address);
    }).then(function(instance) {
        return dinoInstance.setDistributor(Distributor.address);
    }).then(function(instance) {
        return dinoInstance.setDino721(Dino721.address);
    }).then(function(instance) {
        return dinoInstance.setAuction(Auction.address);
    }).then(function(instance) {
        return dinoInstance.setMinter("0x17142514BBb117aa14B80e081eC4423770cCB464"); //test
    }).then(function(instance) {
        return dinoInstance.mint("0x17142514BBb117aa14B80e081eC4423770cCB464", "10000000000000000000000000000"); //test
    }).then(function(instance) {
        return distributorInstance.addRewardPool("0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd", "500000000000000000");
    }).then(function(instance) {
        return distributorInstance.addRewardPool(MockBEP20.address, "500000000000000000"); //test
    }).catch(function(error) {
        console.log(error);
    });
}