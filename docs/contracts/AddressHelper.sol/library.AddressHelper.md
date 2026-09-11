# AddressHelper
[Git Source](https://github.com/passat-b6-tdi/Portcullis/blob/fd346da22903543af8bd77db9de28f1fa6aaf124/contracts/AddressHelper.sol)

**Title:**
Small address-validation helpers shared by Portcullis contracts.


## Functions
### zeroAddressCheck

Reverts unless an address is nonzero.


```solidity
function zeroAddressCheck(address account) external pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Address to validate.|


## Errors
### ZeroAddress
Raised when a required address is the zero address.


```solidity
error ZeroAddress();
```

