// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
/**

编写 IDO 合约，实现 Token 预售，需要实现如下功能：

开启预售: 支持对给定的任意ERC20开启预售，设定预售价格，募集ETH目标，超募上限，预售时长。
任意用户可支付ETH参与预售；
预售结束后，如果没有达到募集目标，则用户可领会退款；
预售成功，用户可领取 Token，且项目方可提现募集的ETH；

 */
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RNT is ERC20("RNT", "RNT"), ERC20Permit("RNT RNT") {
    constructor(address admin) {
        _mint(admin, 1000_0000 * 1e18);
    }
}
contract IDO {
    uint256 public presalePrice = 0.0001 ether;
    uint256 public presaleTokenAmount = 100_0000 * 1e18;
    uint256 public minBuyAmount = 0.01 ether;
    uint256 public maxBuyAmount = 0.1 ether;
    uint256 public minTargetFuns = 100 ether;
    uint256 public maxTargetFuns = 200 ether;
    uint256 public endTime = block.timestamp + 24 hours;
    uint256 public totlePresaleETH;

    RNT public token;
    address public admin;

    constructor(address _token, address _admin) {
        token = RNT(_token);
        admin = _admin;
    }
    struct buyAmount {
        uint256 amount;
        bool isClaim;
    }
    mapping(address => buyAmount) public balances;

    //check IDO whethere or not is on active status
    modifier OnlyActive() {
        require(block.timestamp < endTime, "OnlyActive:now is ddl");
        require(
            totlePresaleETH + msg.value <= maxTargetFuns,
            "OnlyActive:IDO balance have reached maxTargetFuns"
        );
        _;
    }
    //check IDO whethere or not is success
    modifier OnlySuccess() {
        require(block.timestamp > endTime, "have not reached to the ddl");
        require(
            totlePresaleETH >= minTargetFuns,
            "IDO balance is not more than 100 eth"
        );
        _;
    }

    //check IDO whethere or not is faild
    modifier OnlyFaild() {
        require(
            block.timestamp > endTime && totlePresaleETH < minTargetFuns,
            "IDO is failed"
        );
        _;
    }

    //only for admin use
    modifier OnlyAdmin() {
        require(msg.sender == admin, "only for admin");
        _;
    }

    /**
        presale
     */
    function presale() public payable OnlyActive {
        uint256 amount = balances[msg.sender].amount + msg.value;
        totlePresaleETH += msg.value;
        require(
            amount >= minBuyAmount,
            "the amount should more than 0.01 ether"
        );

        require(
            amount <= maxBuyAmount,
            "the amount should less than 0.1 ether"
        );

        balances[msg.sender].amount += msg.value;
    }

    /**
        get token or refund for the user
     */
    function claim() external OnlySuccess {
        uint256 tokenAmount = (presaleTokenAmount *
            balances[msg.sender].amount) / totlePresaleETH;
        balances[msg.sender].isClaim = true;
        token.transfer(msg.sender, tokenAmount);
    }

    /**
        admin get eth 
     */
    function withdraw() external OnlySuccess OnlyAdmin {
        (bool success, ) = payable(admin).call{value: address(this).balance}(
            ""
        );
        require(success, "withdraw failed");
        //payable(address(admin)).transfer(address(this).balance);
    }

    /**
        get refund
    */
    function refund() external OnlyFaild {
        payable(msg.sender).transfer(balances[msg.sender].amount);
        balances[msg.sender].amount = 0;
    }

    function setTotlePresaleETH(uint256 amount) public {
        totlePresaleETH = amount;
    }
    function isSuccess() public view returns (bool) {
        if (block.timestamp > endTime && totlePresaleETH >= minTargetFuns) {
            return true;
        } else {
            return false;
        }
    }

    receive() external payable {
        presale();
    }
}
