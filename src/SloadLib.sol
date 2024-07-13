import "./interfaces/IL1Blocks.sol";
import { FlatBytesLib } from "@rhinestone/flatbytes/src/BytesLib.sol";

address constant L1SLOAD_PRECOMPILE = 0x0000000000000000000000000000000000000101;

address constant L1BLOCKS_PRECOMPILE = 0x5300000000000000000000000000000000000001;

library SloadLib {
    using FlatBytesLib for *;

    function latestL1BlockNumber() public view returns (uint256) {
        uint256 l1BlockNum = IL1Blocks(L1BLOCKS_PRECOMPILE).latestBlockNumber();
        return l1BlockNum;
    }

    function retrieveFromL1(
        address target,
        bytes32 slot
    )
        internal
        view
        returns (bytes memory ret)
    {
        uint256 l1BlockNum = IL1Blocks(L1BLOCKS_PRECOMPILE).latestBlockNumber();
        bytes memory input = abi.encodePacked(l1BlockNum, target, slot);
        bool success;
        (success, ret) = L1SLOAD_PRECOMPILE.staticcall(input);
        require(success, "SloadLib: retrieveFromL1 failed");
    }

    function sload(address target, bytes32 slot) internal view returns (bytes memory ret) {
        FlatBytesLib.Bytes storage local;

        assembly {
            local.slot := slot
        }
        if (local.totalLength != 0) {
            return local.toBytes();
        } else {
            ret = retrieveFromL1(target, slot);
        }
    }
}
