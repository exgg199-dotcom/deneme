#!/usr/bin/env python3
"""Insert an LC_LOAD_WEAK_DYLIB load command into a Mach-O binary.

Writes the new command into the free padding between the end of the
existing load commands and the first section's file data, so no file
offsets shift. Handles fat binaries (patches the arm64 slice) and thin
arm64 Mach-O.

Usage: macho_inject.py <binary> <dylib_install_name>
"""
import sys
import struct

FAT_MAGIC = 0xCAFEBABE
FAT_MAGIC_64 = 0xCAFEBABF
MH_MAGIC_64 = 0xFEEDFACF
MH_CIGAM_64 = 0xCFFAEDFE
CPU_TYPE_ARM64 = 0x0100000C
LC_SEGMENT_64 = 0x19
LC_REQ_DYLD = 0x80000000
LC_LOAD_WEAK_DYLIB = 0x18 | LC_REQ_DYLD


def patch_slice(data, base, dylib_name):
    magic = struct.unpack_from('<I', data, base)[0]
    if magic == MH_MAGIC_64:
        e = '<'
    elif magic == MH_CIGAM_64:
        e = '>'
    else:
        raise RuntimeError(f'not a 64-bit Mach-O slice at 0x{base:x} (magic=0x{magic:08x})')

    # mach_header_64
    (hmagic, cputype, cpusubtype, filetype, ncmds, sizeofcmds,
     flags, reserved) = struct.unpack_from(e + '8I', data, base)
    header_size = 32
    lc_start = base + header_size
    lc_end = lc_start + sizeofcmds

    # Walk load commands, record lowest nonzero section/segment file offset
    lowest = None
    off = lc_start
    for _ in range(ncmds):
        cmd, cmdsize = struct.unpack_from(e + 'II', data, off)
        if cmd == LC_SEGMENT_64:
            (segfileoff, segfilesize) = struct.unpack_from(e + 'QQ', data, off + 32)
            nsects = struct.unpack_from(e + 'I', data, off + 64)[0]
            soff = off + 72  # first section_64 struct
            for _s in range(nsects):
                sect_offset = struct.unpack_from(e + 'I', data, soff + 48)[0]
                if sect_offset != 0:
                    lowest = sect_offset if lowest is None else min(lowest, sect_offset)
                soff += 80
        off += cmdsize

    if lowest is None:
        raise RuntimeError('could not determine first section offset')

    # Build new dylib_command
    name_bytes = dylib_name.encode('utf-8') + b'\x00'
    name_offset = 24  # size of dylib_command fixed part
    cmdsize = name_offset + len(name_bytes)
    if cmdsize % 8:
        cmdsize += 8 - (cmdsize % 8)
    new_cmd = struct.pack(e + 'IIIIII',
                          LC_LOAD_WEAK_DYLIB,
                          cmdsize,
                          name_offset,
                          0,          # timestamp
                          0x10000,    # current_version 1.0.0
                          0x10000)    # compatibility_version 1.0.0
    new_cmd += name_bytes
    new_cmd = new_cmd.ljust(cmdsize, b'\x00')

    # Free space check: [lc_end, base+lowest)
    free = (base + lowest) - lc_end
    if free < cmdsize:
        raise RuntimeError(
            f'not enough padding for load command: need {cmdsize}, have {free}')

    # Verify target region is all zero (safe to overwrite)
    region = data[lc_end:lc_end + cmdsize]
    if any(b != 0 for b in region):
        raise RuntimeError('padding region is not zero; refusing to clobber')

    # Write the command into the padding
    data[lc_end:lc_end + cmdsize] = new_cmd

    # Update header: ncmds+1, sizeofcmds+cmdsize
    struct.pack_into(e + 'II', data, base + 16, ncmds + 1, sizeofcmds + cmdsize)
    print(f'  slice@0x{base:x}: injected (cmdsize={cmdsize}, '
          f'ncmds {ncmds}->{ncmds+1}, free was {free})')


def main():
    path, dylib_name = sys.argv[1], sys.argv[2]
    with open(path, 'rb') as f:
        data = bytearray(f.read())

    magic = struct.unpack_from('>I', data, 0)[0]
    if magic in (FAT_MAGIC, FAT_MAGIC_64):
        nfat = struct.unpack_from('>I', data, 4)[0]
        patched = False
        is64 = magic == FAT_MAGIC_64
        arch_size = 32 if is64 else 20
        for i in range(nfat):
            ao = 8 + i * arch_size
            cputype = struct.unpack_from('>i', data, ao)[0]
            if is64:
                offset = struct.unpack_from('>Q', data, ao + 8)[0]
            else:
                offset = struct.unpack_from('>I', data, ao + 8)[0]
            if cputype == CPU_TYPE_ARM64:
                patch_slice(data, offset, dylib_name)
                patched = True
        if not patched:
            raise RuntimeError('no arm64 slice in fat binary')
    elif magic in (MH_MAGIC_64, MH_CIGAM_64) or \
            struct.unpack_from('<I', data, 0)[0] in (MH_MAGIC_64, MH_CIGAM_64):
        patch_slice(data, 0, dylib_name)
    else:
        raise RuntimeError(f'unknown magic 0x{magic:08x}')

    with open(path, 'wb') as f:
        f.write(data)
    print(f'  wrote {path}')


if __name__ == '__main__':
    main()
