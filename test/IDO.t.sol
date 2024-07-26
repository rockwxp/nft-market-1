// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import {IDO, RNT} from "../src/IDO.sol";

contract IDOTest is Test {
    RNT public token;
    IDO public ido;
    address admin;
    address user_1;
    address user_2;
    address user_3;

    function setUp() public {
        admin = address(1);
        token = new RNT(admin);

        console.log("admin address:", address(admin));
        console.log("adimin token amont:", token.balanceOf(address(admin)));
        ido = new IDO(address(token), admin);

        user_1 = address(2);
        user_2 = address(3);
        user_3 = address(4);
        vm.deal(user_1, 50 ether);
        vm.deal(user_2, 50 ether);
        vm.deal(user_3, 50 ether);
    }

    //forge test --match-path test/IDO.t.sol --match-test test_presale -vv
    function test_presale() public {
        vm.startPrank(user_1);
        console.log("user_1 balance:", address(user_1).balance);
        //buy token
        ido.presale{value: 0.02 ether}();
        console.log("ido contract balance:", address(ido).balance);
        console.log("user_1 balance:", address(user_1).balance);
        (uint256 amount, ) = ido.balances(user_1);
        console.log("user_1 ido eth balance", amount);

        assertEq(address(ido).balance, 0.02 * 1e18, "ido contract is wrong");
        vm.stopPrank();
    }

    function test_presale_2() public {
        vm.startPrank(user_1);
        console.log("user_1 balance:", address(user_1).balance);
        //buy token
        ido.presale{value: 1 ether}();
        console.log("ido contract balance:", address(ido).balance);
        console.log("user_1 balance:", address(user_1).balance);
        (uint256 amount, ) = ido.balances(user_1);
        console.log("user_1 ido eth balance", amount);

        assertEq(address(ido).balance, 0.02 * 1e18, "ido contract is wrong");
        vm.stopPrank();
    }

    function test_claim() public {
        uint256 presaleTokenAmount = ido.presaleTokenAmount();
        vm.prank(admin);
        token.transfer(address(ido), presaleTokenAmount);

        vm.startPrank(user_1);
        //presale
        ido.presale{value: 0.05 ether}();
        //set maxTargetFuns
        vm.deal(address(ido), 200 ether);
        ido.setTotlePresaleETH(200 * 1e18);

        //set ddl
        vm.warp(block.timestamp + 25 hours);
        ido.claim();
        (uint256 ethAmount, ) = ido.balances(user_1);
        uint256 userTokenAmount = (presaleTokenAmount * ethAmount) /
            ido.totlePresaleETH();
        assertEq(
            token.balanceOf(user_1),
            userTokenAmount,
            "Incorrect user token amount"
        );
        vm.stopPrank();
    }
}
