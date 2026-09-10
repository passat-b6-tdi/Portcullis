// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Test } from "forge-std/Test.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { AddressHelper } from "../../contracts/AddressHelper.sol";
import { AddressBookRegistry } from "../../contracts/identity/AddressBookRegistry.sol";
import { EnsIdentityRegistry } from "../../contracts/identity/EnsIdentityRegistry.sol";
import { MockUniversalResolver } from "../mocks/MockEns.sol";

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
    MockUniversalResolver internal ur;
    EnsIdentityRegistry internal registry;

    address internal owner = makeAddr("owner");
    address internal stranger = makeAddr("stranger");
    bytes32 internal constant NODE = keccak256("treasury.acme.eth");
    address internal authority = makeAddr("authority");

    // DNS-encoded "treasury.acme.eth"
    bytes internal constant DNS_NAME = hex"0874726561737572790461636d650365746800";

    function setUp() public {
        ur = new MockUniversalResolver();
        registry = new EnsIdentityRegistry(address(ur), owner);
        ur.setAddr(NODE, authority);
    }

    function _allow(bytes32 node) internal {
        vm.prank(owner);
        registry.allow(node, DNS_NAME);
    }

    function test_constructor_rejectsZeroResolver() public {
        vm.expectRevert(AddressHelper.ZeroAddress.selector);
        new EnsIdentityRegistry(address(0), owner);
    }

    function test_constructor_rejectsZeroOwner() public {
        vm.expectRevert(AddressHelper.ZeroAddress.selector);
        new EnsIdentityRegistry(address(ur), address(0));
    }

    function test_allow_onlyOwner() public {
        vm.prank(stranger);
        vm.expectRevert(Ownable.Unauthorized.selector);
        registry.allow(NODE, DNS_NAME);
    }

    function test_allow_rejectsEmptyName() public {
        vm.prank(owner);
        vm.expectRevert(EnsIdentityRegistry.EmptyName.selector);
        registry.allow(NODE, "");
    }

    function test_notAllowlisted_resolvesZero() public view {
        assertEq(registry.resolve(NODE), address(0));
    }

    function test_allowlistedWithRecord_returnsAddr() public {
        _allow(NODE);
        assertEq(registry.resolve(NODE), authority);
    }

    function test_revoke_stopsResolving() public {
        _allow(NODE);
        assertEq(registry.resolve(NODE), authority);
        vm.prank(owner);
        registry.revoke(NODE);
        assertEq(registry.resolve(NODE), address(0));
    }

    function test_noResolver_resolvesZero() public {
        _allow(NODE);
        ur.setMode(MockUniversalResolver.Mode.ResolverMissing);
        assertEq(registry.resolve(NODE), address(0));
    }

    function test_resolverReverts_resolvesZero() public {
        _allow(NODE);
        ur.setMode(MockUniversalResolver.Mode.ResolverDown);
        assertEq(registry.resolve(NODE), address(0));
    }

    function test_offchainLookup_resolvesZero() public {
        _allow(NODE);
        ur.setMode(MockUniversalResolver.Mode.Offchain);
        assertEq(registry.resolve(NODE), address(0));
    }

    function test_emptyResult_resolvesZero() public {
        _allow(NODE);
        ur.setMode(MockUniversalResolver.Mode.EmptyResult);
        assertEq(registry.resolve(NODE), address(0));
    }

    function test_resolverSetButNoRecord_resolvesZero() public {
        bytes32 blank = keccak256("blank.acme.eth");
        ur.setHasResolver(blank, true);
        _allow(blank);
        assertEq(registry.resolve(blank), address(0));
    }

    function test_allowBatch_setsMany() public {
        bytes32 ops = keccak256("ops.acme.eth");
        ur.setAddr(ops, stranger);

        bytes32[] memory nodes = new bytes32[](2);
        bytes[] memory names = new bytes[](2);
        nodes[0] = NODE;
        nodes[1] = ops;
        names[0] = DNS_NAME;
        names[1] = DNS_NAME;

        vm.prank(owner);
        registry.allowBatch(nodes, names);

        assertEq(registry.resolve(NODE), authority);
        assertEq(registry.resolve(ops), stranger);
    }
}
