// SPDX-License-Identifier: MIT

module private_sale::safe_math {
    const EOverflow: u64 = 1;

    public fun add(a:u64, b:u64): u64 {
        let c = a + b;
        assert!(c > a, EOverflow);

        c
    }

    public fun sub(a:u64, b:u64): u64 {
        assert!(a > b, EOverflow);

        a - b
    }
}