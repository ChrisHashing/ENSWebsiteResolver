// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@ensdomains/ens-contracts/contracts/registry/ENS.sol";
import "@ensdomains/ens-contracts/contracts/resolvers/profiles/AddrResolver.sol";

contract ENSWebsiteResolver is Ownable, AddrResolver {
    ENS public ens;
    mapping(bytes32 => address) private websites;
    mapping(address => bytes32) private reverseWebsites;

    address payable public feeRecipient;
    uint256 public registrationFee;
    uint256 public updateFee;
    uint256 public removalFee;

    event WebsiteAddrChanged(bytes32 indexed node, address addr);
    event WebsiteAddrRemoved(bytes32 indexed node);
    event FeeRecipientChanged(address indexed oldRecipient, address indexed newRecipient);
    event FeesUpdated(uint256 registrationFee, uint256 updateFee, uint256 removalFee);

    constructor(ENS _ens, address payable _feeRecipient) {
        require(address(_ens) != address(0), "Invalid ENS registry address");
        require(_feeRecipient != address(0), "Invalid fee recipient address");
        ens = _ens;
        feeRecipient = _feeRecipient;
        registrationFee = 0.1 ether; // Default fees, can be changed by owner
        updateFee = 0.05 ether;
        removalFee = 0.01 ether;
    }

    modifier onlyENSOwner(bytes32 node) {
        require(msg.sender == ens.owner(node), "Not the ENS domain owner");
        _;
    }

    modifier paysFee(uint256 fee) {
        require(msg.value >= fee, "Insufficient fee");
        _;
    }

    function setWebsiteAddr(bytes32 node, address addr) public payable onlyENSOwner(node) paysFee(registrationFee) {
        require(addr != address(0), "Invalid website contract address");
        require(websites[node] == address(0), "Website already registered");
        
        websites[node] = addr;
        reverseWebsites[addr] = node;
        emit WebsiteAddrChanged(node, addr);
        
        _sendFee(registrationFee);
    }

    function updateWebsiteAddr(bytes32 node, address newAddr) public payable onlyENSOwner(node) paysFee(updateFee) {
        require(newAddr != address(0), "Invalid website contract address");
        require(websites[node] != address(0), "Website not registered");
        
        address oldAddr = websites[node];
        websites[node] = newAddr;
        delete reverseWebsites[oldAddr];
        reverseWebsites[newAddr] = node;
        emit WebsiteAddrChanged(node, newAddr);
        
        _sendFee(updateFee);
    }

    function removeWebsiteAddr(bytes32 node) public payable onlyENSOwner(node) paysFee(removalFee) {
        require(websites[node] != address(0), "Website not registered");
        
        address addr = websites[node];
        delete websites[node];
        delete reverseWebsites[addr];
        emit WebsiteAddrRemoved(node);
        
        _sendFee(removalFee);
    }

    function websiteAddr(bytes32 node) public view returns (address) {
        return websites[node];
    }

    function reverseWebsiteNode(address addr) public view returns (bytes32) {
        return reverseWebsites[addr];
    }

    // Implement AddrResolver interface
    function addr(bytes32 node) public view override returns (address payable) {
        return payable(websites[node]);
    }

    function setAddr(bytes32 node, address addr) public payable override onlyENSOwner(node) paysFee(registrationFee) {
        setWebsiteAddr(node, addr);
    }

    // Implement supportsInterface from ERC165
    function supportsInterface(bytes4 interfaceID) public pure override returns (bool) {
        return interfaceID == type(AddrResolver).interfaceId || super.supportsInterface(interfaceID);
    }

    // Allow the contract owner to update the ENS registry address if needed
    function updateENSRegistry(ENS _ens) public onlyOwner {
        require(address(_ens) != address(0), "Invalid ENS registry address");
        ens = _ens;
    }

    // Allow the contract owner to update the fee recipient
    function setFeeRecipient(address payable _feeRecipient) public onlyOwner {
        require(_feeRecipient != address(0), "Invalid fee recipient address");
        emit FeeRecipientChanged(feeRecipient, _feeRecipient);
        feeRecipient = _feeRecipient;
    }

    // Allow the contract owner to update the fees
    function setFees(uint256 _registrationFee, uint256 _updateFee, uint256 _removalFee) public onlyOwner {
        registrationFee = _registrationFee;
        updateFee = _updateFee;
        removalFee = _removalFee;
        emit FeesUpdated(registrationFee, updateFee, removalFee);
    }

    // Internal function to send fees
    function _sendFee(uint256 fee) private {
        uint256 excessFee = msg.value - fee;
        (bool sent, ) = feeRecipient.call{value: fee}("");
        require(sent, "Failed to send fee");
        if (excessFee > 0) {
            (bool refunded, ) = msg.sender.call{value: excessFee}("");
            require(refunded, "Failed to refund excess fee");
        }
    }

    // Allow the contract to receive ETH
    receive() external payable {}

    // Allow the contract owner to withdraw any ETH balance
    function withdrawBalance() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        (bool sent, ) = owner().call{value: balance}("");
        require(sent, "Failed to send balance");
    }

    // Allow the contract owner to recover any accidentally sent ERC20 tokens
    function recoverERC20(address tokenAddress, uint256 tokenAmount) public onlyOwner {
        IERC20(tokenAddress).transfer(owner(), tokenAmount);
    }
}