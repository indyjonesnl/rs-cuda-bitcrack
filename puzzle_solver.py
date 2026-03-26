#!/usr/bin/env python3
"""
Bitcoin Puzzle Solver - Python Reference Implementation
Cross-check solution for rs-cuda-bitcrack

Usage:
    ./puzzle_solver.py --address ADDRESS --min HEX --max HEX
"""

import argparse
import hashlib
import sys
from typing import Optional

# Try to import ripemd160 - handle OpenSSL 3.0+ which disabled it by default
try:
    # Test if ripemd160 is available
    hashlib.new('ripemd160')
    RIPEMD160_AVAILABLE = True
except ValueError:
    RIPEMD160_AVAILABLE = False
    # Fallback: use pure Python implementation
    try:
        from Crypto.Hash import RIPEMD160 as RIPEMD_Crypto
        HAS_PYCRYPTO = True
    except ImportError:
        HAS_PYCRYPTO = False


# Secp256k1 constants
P = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F
N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
Gx = 0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798
Gy = 0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8


def modinv(a: int, m: int) -> int:
    """Modular multiplicative inverse using Extended Euclidean Algorithm"""
    if a < 0:
        a = (a % m + m) % m
    g, x, _ = extended_gcd(a, m)
    if g != 1:
        raise ValueError('Modular inverse does not exist')
    return x % m


def extended_gcd(a: int, b: int) -> tuple:
    """Extended Euclidean Algorithm"""
    if a == 0:
        return b, 0, 1
    gcd, x1, y1 = extended_gcd(b % a, a)
    x = y1 - (b // a) * x1
    y = x1
    return gcd, x, y


def point_add(p1: Optional[tuple], p2: Optional[tuple]) -> Optional[tuple]:
    """Add two points on the secp256k1 curve"""
    if p1 is None:
        return p2
    if p2 is None:
        return p1

    x1, y1 = p1
    x2, y2 = p2

    if x1 == x2:
        if y1 == y2:
            # Point doubling
            s = (3 * x1 * x1 * modinv(2 * y1, P)) % P
        else:
            # Points are inverses
            return None
    else:
        # Point addition
        s = ((y2 - y1) * modinv(x2 - x1, P)) % P

    x3 = (s * s - x1 - x2) % P
    y3 = (s * (x1 - x3) - y1) % P
    return (x3, y3)


def scalar_mult(k: int, point: tuple) -> Optional[tuple]:
    """Multiply a point by a scalar using double-and-add algorithm"""
    if k == 0:
        return None
    if k < 0:
        raise ValueError("Scalar must be non-negative")

    result = None
    addend = point

    while k:
        if k & 1:
            result = point_add(result, addend)
        addend = point_add(addend, addend)
        k >>= 1

    return result


def ripemd160(data: bytes) -> bytes:
    """Compute RIPEMD160 hash with fallback for OpenSSL 3.0+"""
    if RIPEMD160_AVAILABLE:
        return hashlib.new('ripemd160', data).digest()
    elif HAS_PYCRYPTO:
        h = RIPEMD_Crypto.new()
        h.update(data)
        return h.digest()
    else:
        raise RuntimeError(
            "RIPEMD160 not available. Install pycryptodome: pip install pycryptodome"
        )


def public_key_to_address(public_key: tuple, compressed: bool = True) -> str:
    """Convert public key to Bitcoin P2PKH address"""
    x, y = public_key

    if compressed:
        # Compressed: 02/03 prefix + x coordinate
        prefix = b'\x02' if y % 2 == 0 else b'\x03'
        public_key_bytes = prefix + x.to_bytes(32, 'big')
    else:
        # Uncompressed: 04 prefix + x + y coordinates
        public_key_bytes = b'\x04' + x.to_bytes(32, 'big') + y.to_bytes(32, 'big')

    # Hash160: RIPEMD160(SHA256(public_key))
    sha256_hash = hashlib.sha256(public_key_bytes).digest()
    ripemd160_hash = ripemd160(sha256_hash)

    # P2PKH address: version (0x00) + hash160 + checksum
    version = b'\x00'
    payload = version + ripemd160_hash
    checksum = hashlib.sha256(hashlib.sha256(payload).digest()).digest()[:4]

    # Base58 encode
    address_bytes = payload + checksum
    return base58_encode(address_bytes)


def base58_encode(data: bytes) -> str:
    """Encode bytes to Base58"""
    alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'

    # Convert bytes to integer
    num = int.from_bytes(data, 'big')

    # Convert to base58
    encoded = ''
    while num > 0:
        num, remainder = divmod(num, 58)
        encoded = alphabet[remainder] + encoded

    # Add leading '1's for leading zero bytes
    for byte in data:
        if byte == 0:
            encoded = '1' + encoded
        else:
            break

    return encoded


def search_address(target_address: str, min_key: int, max_key: int) -> Optional[int]:
    """Search for private key that generates target address"""
    print(f"Python Solver - Searching for: {target_address}")
    print(f"Range: 0x{min_key:x} to 0x{max_key:x} ({max_key - min_key + 1} keys)")
    print()

    # Generator point
    G = (Gx, Gy)

    # Progress reporting
    total_keys = max_key - min_key + 1
    report_interval = max(1, total_keys // 100)  # Report every 1%

    for private_key in range(min_key, max_key + 1):
        # Generate public key
        public_key = scalar_mult(private_key, G)
        if public_key is None:
            continue

        # Generate address (compressed P2PKH)
        address = public_key_to_address(public_key, compressed=True)

        # Check if matches
        if address == target_address:
            return private_key

        # Progress reporting
        if (private_key - min_key) % report_interval == 0 and private_key != min_key:
            progress = 100.0 * (private_key - min_key + 1) / total_keys
            print(f"Progress: {progress:.1f}% (checked {private_key - min_key + 1}/{total_keys} keys)", end='\r')

    print()  # Clear progress line
    return None


def main():
    parser = argparse.ArgumentParser(
        description='Bitcoin Puzzle Solver - Python Reference Implementation'
    )
    parser.add_argument('--address', required=True, help='Target Bitcoin address')
    parser.add_argument('--min', required=True, help='Minimum private key (hex, without 0x)')
    parser.add_argument('--max', required=True, help='Maximum private key (hex, without 0x)')

    args = parser.parse_args()

    # Parse hex ranges
    try:
        min_key = int(args.min, 16)
        max_key = int(args.max, 16)
    except ValueError as e:
        print(f"Error parsing hex values: {e}", file=sys.stderr)
        sys.exit(1)

    if min_key > max_key:
        print(f"Error: min ({args.min}) must be <= max ({args.max})", file=sys.stderr)
        sys.exit(1)

    # Search
    print("=" * 50)
    print("Bitcoin Puzzle Solver (Python)")
    print("=" * 50)

    result = search_address(args.address, min_key, max_key)

    if result is not None:
        print()
        print("✓ FOUND!")
        print(f"Private key: {result:064x}")
        print(f"Private key (decimal): {result}")
        sys.exit(0)
    else:
        print()
        print("✗ Not found in range")
        sys.exit(1)


if __name__ == '__main__':
    main()
