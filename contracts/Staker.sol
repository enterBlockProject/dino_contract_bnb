// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./library/BEP20.sol";
import "./library/SafeMath.sol";
import "./library/SafeBEP20.sol";
import "./interfaces/IDino.sol";

contract Staker is BEP20("SDino", "SDino") {
    using SafeMath for uint;
    using SafeBEP20 for IBEP20;

    IBEP20 public dino;

    event Staked(
        address indexed account,
        uint amount,
        uint shares);

    event Unstaked(
        address indexed account,
        uint amount,
        uint shares);

    constructor (address _dino) {
        dino = IBEP20(_dino);
    }

    function setDino(address _dino) public {
        require(msg.sender == IDino(address(dino)).admin(), "Dino: admin");
        dino = IBEP20(_dino);
    }

    function stake(uint amount) public {
        uint totalBalance = dino.balanceOf(address(this));
        uint mintShares = totalBalance == 0
            ? amount
            : amount
                .mul(totalSupply())
                .div(totalBalance);

        _mint(msg.sender, mintShares);
        dino.safeTransferFrom(msg.sender, address(this), amount);

        emit Staked(msg.sender, amount, mintShares);
    }

    function unstake(uint shares) public {
        uint unstakeAmount = shares
            .mul(dino.balanceOf(address(this)))
            .div(totalSupply());

        _burn(msg.sender, shares);
        dino.safeTransfer(msg.sender, unstakeAmount);

        emit Unstaked(msg.sender, unstakeAmount, shares);
    }
}