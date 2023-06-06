// SPDX-License-Identifier: MIT

module private_sale::safe_math {

    public fun add(a:u64, b:u64): u64 {
        let c = a + b;
        assert!(c > a, 0);

        c
    }

    public fun sub(a:u64, b:u64): u64 {
        assert!(a > b, 0);

        a - b
    }
}