// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Test } from "forge-std/Test.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { AddressHelper } from "../../contracts/AddressHelper.sol";
import { AddressBookRegistry } from "../../contracts/identity/AddressBookRegistry.sol";
import { EnsIdentityRegistry, IEnsRegistry } from "../../contracts/identity/EnsIdentityRegistry.sol";
import { MockEnsRegistry, MockEnsResolver } from "../mocks/MockEns.sol";

contract AddressBookRegistryTest is Test {
    AddressBookRegistry internal book;
    address internal owner = makeAddr("owner");
    address internal stranger = makeAddr("stranger");
    bytes32 internal constant SRC = keccak256("treasury.acme.portcullis.eth");
    address internal authority = makeAddr("authority");

    function setUp() public {
        book = new AddressBookRegistry(owner);
    }

    function test_constructor_rejectsZeroOwner() public {
        vm.expectRevert(AddressHelper.ZeroAddress.selector);
        new AddressBookRegistry(address(0));
    }

    function test_unknownSource_resolvesZero() public view {
        assertEq(book.resolve(SRC), address(0));
    }

    function test_setAuthority_onlyOwner() public {
        vm.prank(stranger);
        vm.expectRevert(Ownable.Unauthorized.selector);
        book.setAuthority(SRC, authority);
    }

    function test_setAndResolve() public {
        vm.prank(owner);
        book.setAuthority(SRC, authority);
        assertEq(book.resolve(SRC), authority);
    }

    function test_batchSet() public {
        bytes32[] memory ids = new bytes32[](2);
        address[] memory addrs = new address[](2);
        ids[0] = SRC;
        ids[1] = keccak256("ops.acme.portcullis.eth");
        addrs[0] = authority;
        addrs[1] = stranger;

        vm.prank(owner);
        book.setAuthorities(ids, addrs);

        assertEq(book.resolve(ids[0]), authority);
        assertEq(book.resolve(ids[1]), stranger);
    }

    function test_transferOwnership() public {
        vm.prank(owner);
        book.transferOwnership(stranger);
        assertEq(book.owner(), stranger);

        vm.prank(stranger);
        book.setAuthority(SRC, authority);
        assertEq(book.resolve(SRC), authority);
    }
}

contract EnsIdentityRegistryTest is Test {
    MockEnsRegistry internal ens;
    MockEnsResolver internal resolver;
    EnsIdentityRegistry internal registry;

    bytes32 internal constant NODE = keccak256("treasury.acme.portcullis.eth");
    address internal authority = makeAddr("authority");

    function setUp() public {
        ens = new MockEnsRegistry();
        resolver = new MockEnsResolver();
        registry = new EnsIdentityRegistry(address(ens));
    }

    function test_constructor_rejectsZeroEns() public {
        vm.expectRevert(AddressHelper.ZeroAddress.selector);
        new EnsIdentityRegistry(address(0));
    }

    function test_noResolver_resolvesZero() public view {
        assertEq(registry.resolve(NODE), address(0));
    }

    function test_resolverSet_returnsAddr() public {
        ens.setResolver(NODE, address(resolver));
        resolver.setAddr(NODE, authority);
        assertEq(registry.resolve(NODE), authority);
    }

    function test_resolverReverts_resolvesZero() public {
        ens.setResolver(NODE, address(resolver));
        resolver.setAddr(NODE, authority);
        resolver.setRevert(true);
        assertEq(registry.resolve(NODE), address(0));
    }

    function test_resolverSetButNoRecord_resolvesZero() public {
        ens.setResolver(NODE, address(resolver));
        assertEq(registry.resolve(NODE), address(0));
    }
}
