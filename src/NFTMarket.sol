// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

//签名流程：
//1. 将 函数结构体 进行keccak256 hash 生成 TypeHash
//2. 用abi.encode组装TypeHash和函数结构体的value，再次进行keccak256 hash 生成 生成hash
//3. 使用用户私钥对哈希进行签名 生成签名

//验证签名
//1. 同上
//2. 同上 生成hash
//3. 用ECDSA.recover(签名，hash) 生成 address
//4. 验证address 是否和当前操作者(签名者)一样

contract NFTMarket is Ownable(msg.sender), EIP712("OpenSpaceNFTMarket", "1") {
    address public constant ETH_FLAG =
        address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE); //set token 是 ETH 的标识
    uint256 public constant feeBP = 30; //设定手续费率 30/10000= 0.3%
    address public whiteListSigner; //白名单签名者
    address public feeTo; //手续费接受方
    mapping(bytes32 => SellOrder) public listingOrders; // orderId -> order book 已经上架售卖的NFT订单
    mapping(address => mapping(uint256 => bytes32)) private _lastIds; //  nft -> (tokenId -> orderId)

    struct SellOrder {
        address seller;
        address nft;
        uint256 tokenId;
        address payToken;
        uint256 price;
        uint256 deadline;
    }
    //查询orderId
    function listing(
        address nft,
        uint256 tokenId
    ) external view returns (bytes32) {
        bytes32 id = _lastIds[nft][tokenId];
        return listingOrders[id].seller == address(0) ? bytes32(0x00) : id;
    }

    //上架NFT
    function list(
        address nft,
        uint256 tokenId,
        address payToken,
        uint256 price,
        uint256 deadline
    ) external {
        require(deadline > block.timestamp, "deadline is in the past");
        require(price > 0, "price is zero");
        require(
            payToken == address(0) || IERC20(payToken).totalSupply() > 0, //paytoken 是 ETH 或者是其他ERC20 token
            "payToken invalid"
        );

        require(IERC721(nft).ownerOf(tokenId) == msg.sender, "not owner"); //上架操作必须是 nft owner 执行
        require(
            IERC721(nft).getApproved(tokenId) == address(this) || // nft授权给当前合约
                IERC721(nft).isApprovedForAll(msg.sender, address(this)), //当前合约地址是owner的操作员
            "not approved"
        );

        SellOrder memory order = SellOrder({
            seller: msg.sender,
            nft: nft,
            tokenId: tokenId,
            payToken: payToken,
            price: price,
            deadline: deadline
        });

        bytes32 orderId = keccak256(abi.encode(order)); //生成order的唯一ID
        require(
            listingOrders[orderId].seller == address(0), //检查order是否已经上架
            "the order already listed"
        );
        listingOrders[orderId] = order; //上架
        _lastIds[nft][tokenId] = orderId; //记录orderId
        emit List(nft, tokenId, orderId, msg.sender, payToken, price, deadline);
    }

    //下架
    function cancel(bytes32 orderId) external {
        address seller = listingOrders[orderId].seller; //获取nft owner
        address nft = listingOrders[orderId].nft;
        uint256 tokenId = listingOrders[orderId].tokenId;
        require(seller != address(0), "order not listed"); //确定是否已经上架
        require(seller == msg.sender, " only seller can cancel"); //验证操作者是不是nft owner
        delete listingOrders[orderId]; //下架
        delete _lastIds[nft][tokenId];
        emit Cancel(orderId);
    }

    function buy(bytes32 orderId) public payable {
        _buy(orderId, feeTo);
    }

    //
    function buy(
        bytes32 orderId,
        bytes calldata signatureForWL
    ) external payable {
        _checkWL(signatureForWL);
        // trade fee is zero
        _buy(orderId, address(0));
    }

    function _buy(bytes32 orderId, address feeReceiver) private {
        SellOrder memory order = listingOrders[orderId]; //获取上架的NFT信息
        require(order.seller != address(0), "MKT: order not listed"); //检查nft是否上架
        require(order.deadline > block.timestamp, "MKT: order expired"); //检查当前时间是否超过了有效期

        delete listingOrders[orderId]; // 转移nft前 下架NFT

        IERC721(order.nft).safeTransferFrom( //转移NFT  如果 to 是合约将触发回掉
                order.seller,
                msg.sender,
                order.tokenId
            );
        //4. transfer token, fee 0.3% or 0
        uint256 fee = feeReceiver == address(0) //如果没有feeReceiver，就免手续费
            ? 0
            : (order.price * feeBP) / 10000;

        //safe check
        if (order.payToken == ETH_FLAG) {
            require(msg.value == order.price, "MKT: wrong eth value"); //ETH 的价格要订单价格一致
        } else {
            require(msg.value == 0, "MKT: wrong eth value"); //如果是用ERC20token，就不需要ETH value
        }
        _transferOut(order.payToken, order.seller, order.price - fee); //由卖家承担手续费
        if (fee > 0) _transferOut(order.payToken, feeReceiver, fee); //如果有手续费，就向项目方支付手续费

        emit Sold(orderId, msg.sender, fee);
    }

    //转账 token
    function _transferOut(address token, address to, uint256 amount) private {
        if (token == ETH_FLAG) {
            // eth
            (bool success, ) = to.call{value: amount}(""); //to 直接收取 msg.sender 的eth
            require(success, "MKT: transfer failed");
        } else {
            SafeERC20.safeTransferFrom(IERC20(token), msg.sender, to, amount); //？？
        }
    }

    //开始验证签名
    bytes32 constant WL_TYPEHASH = keccak256("IsWhiteList(address user)"); //确定TYPEHASH

    //检查签名是否在白名单中
    function _checkWL(bytes calldata signature) private view {
        bytes32 wlHash = _hashTypedDataV4(
            keccak256(abi.encode(WL_TYPEHASH, msg.sender)) //生成 EIP-712哈希 hashtype对应的value(msg.sender) 防止别人使用使用签名
        );
        address signer = ECDSA.recover(wlHash, signature); //恢复签名这地址
        require(signer == whiteListSigner, "not whiteListSigner");
    }

    //admin function
    function setWhithListSigner(address signer) external onlyOwner {
        require(signer != address(0), "zero address");
        require(whiteListSigner != signer, "repeat signer");
        whiteListSigner = signer;

        emit SetWhiteListSigner(signer);
    }

    function setFeeTo(address to) external onlyOwner {
        require(feeTo != to, "repeat feeTo");
        require(feeTo != address(0), "zero address");
        feeTo = to;
        emit SetFeeTo(to);
    }

    event List(
        address indexed nft,
        uint256 indexed tokenId,
        bytes32 orderId,
        address seller,
        address payToken,
        uint256 price,
        uint256 deadline
    );
    event Cancel(bytes32 orderId);
    event Sold(bytes32 orderId, address buyer, uint256 fee);
    event SetFeeTo(address to);
    event SetWhiteListSigner(address signer);
}
