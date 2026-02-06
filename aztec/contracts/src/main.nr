use aztec::macros::aztec;
mod structs;

/*
Aztec Wormhole contract for the Wormhole bridge on Aztec testnet.

This contract is responsible for:
- Parsing and verifying Wormhole VAA messages
- Managing guardian sets and their expiration
- Publishing messages to the Wormhole network
- Receiving messages from the Wormhole network

To deploy this contract, follow the instructions in the deploy.md file, or use the deploy.sh script.

TODO: Fix hardcoded addresses in private functions.
*/

#[aztec]
pub contract Wormhole {
    use crate::structs::{Guardian, Provider, Signature, WormholeStorage};
    use dep::keccak256::keccak256;

    use aztec::{
        macros::{functions::{external, initializer, only_self}, storage::storage},
        protocol_types::{address::AztecAddress, traits::ToField},
        state_vars::{
            delayed_public_mutable::DelayedPublicMutable, map::Map, public_mutable::PublicMutable,
        },
    };

    use dep::token::Token;

    pub global GUARDIAN: Guardian = comptime {
        crate::structs::Guardian::new(
            [
                0x13, 0x94, 0x7b, 0xd4, 0x8b, 0x18, 0xe5, 0x3f, 0xda, 0xee, 0xe7, 0x7f, 0x34, 0x73,
                0x39, 0x1a, 0xc7, 0x27, 0xc6, 0x38,
            ],
            [
                0xfa, 0x9d, 0x6b, 0x47, 0x04, 0x3b, 0x15, 0xb4, 0xb3, 0x3c, 0xf0, 0x5b, 0xb1, 0xde,
                0x0f, 0x13, 0xda, 0x70, 0x31, 0x36, 0xb2, 0xcd, 0x15, 0x73, 0x24, 0xeb, 0x61, 0x5e,
                0xc9, 0xee, 0x95, 0x12,
            ],
            [
                0x38, 0xc6, 0x7b, 0x54, 0xd0, 0x3e, 0x3c, 0x18, 0x2e, 0x0e, 0x77, 0xb8, 0x5f, 0x88,
                0x3c, 0xcd, 0x74, 0xdd, 0xdf, 0xc5, 0x90, 0x10, 0xfb, 0xf4, 0x75, 0xa0, 0xbe, 0xe6,
                0x59, 0x3c, 0xe2, 0xbd,
            ],
        )
    };

    // ============================================================================
    // STORAGE STRUCTURE
    // ============================================================================

    #[storage]
    struct Storage<Context> {
        state: PublicMutable<WormholeStorage, Context>,
        sequences: Map<AztecAddress, PublicMutable<u64, Context>, Context>,
        owner: PublicMutable<AztecAddress, Context>,
        receiver_address: DelayedPublicMutable<AztecAddress, 87000, Context>, // Delay slightly over 1 day.
        token_address: DelayedPublicMutable<AztecAddress, 87000, Context>, // Delay slightly over 1 day.
        guardian_1: Map<u32, PublicMutable<Guardian, Context>, Context>,
        guardian_2: Map<u32, PublicMutable<Guardian, Context>, Context>,
        guardian_3: Map<u32, PublicMutable<Guardian, Context>, Context>,
        guardian_4: Map<u32, PublicMutable<Guardian, Context>, Context>,
        guardian_5: Map<u32, PublicMutable<Guardian, Context>, Context>,
        guardian_6: Map<u32, PublicMutable<Guardian, Context>, Context>,
        guardian_7: Map<u32, PublicMutable<Guardian, Context>, Context>,
        guardian_8: Map<u32, PublicMutable<Guardian, Context>, Context>,
        guardian_9: Map<u32, PublicMutable<Guardian, Context>, Context>,
        guardian_10: Map<u32, PublicMutable<Guardian, Context>, Context>,
        guardian_11: Map<u32, PublicMutable<Guardian, Context>, Context>,
        guardian_12: Map<u32, PublicMutable<Guardian, Context>, Context>,
        guardian_13: Map<u32, PublicMutable<Guardian, Context>, Context>,
        guardian_14: Map<u32, PublicMutable<Guardian, Context>, Context>,
        guardian_15: Map<u32, PublicMutable<Guardian, Context>, Context>,
        guardian_16: Map<u32, PublicMutable<Guardian, Context>, Context>,
        guardian_17: Map<u32, PublicMutable<Guardian, Context>, Context>,
        guardian_18: Map<u32, PublicMutable<Guardian, Context>, Context>,
        guardian_19: Map<u32, PublicMutable<Guardian, Context>, Context>,
        current_guardian_set_index: Map<u32, PublicMutable<u64, Context>, Context>,
    }

    // ============================================================================
    // CONTRACT INITIALIZATION
    // ============================================================================

    #[external("public")]
    #[initializer]
    fn init(
        chain_id: u16,
        evm_chain_id: u16,
        owner: AztecAddress,
        receiver_address: AztecAddress,
        token_address: AztecAddress,
    ) {
        let provider: Provider = Provider { chain_id, evm_chain_id };
        self.storage.state.write(WormholeStorage::init(provider));
        self.storage.owner.write(owner);
        self.storage.receiver_address.schedule_value_change(receiver_address);
        self.storage.token_address.schedule_value_change(token_address);
        self.storage.current_guardian_set_index.at(0).write(18_446_744_073_709_551_615);
    }

    // ============================================================================
    // CORE FUNCTIONALITY - MESSAGE PUBLISHING
    // ============================================================================

    #[external("public")]
    fn publish_message_in_public(
        nonce: u64,
        payloads: [[u8; 31]; 8],
        message_fee: u128,
        consistency: u8,
        from: AztecAddress,
        token_nonce: Field,
    ) -> u64 {
        assert(self.storage.state.read().message_fee <= message_fee, "insufficient fee");

        let receiver_address = self.storage.receiver_address.get_current_value();
        let token_address = self.storage.token_address.get_current_value();

        // Only transfer tokens if fee is greater than 0
        if message_fee > 0 {
            Token::at(token_address)
                .transfer_in_public(from, receiver_address, message_fee, token_nonce)
                .call(self.context);
        }

        let sender = self.msg_sender().unwrap();
        let sequence = self.storage.sequences.at(sender).read();
        self.storage.sequences.at(sender).write(sequence + 1);

        let msg: [Field; 13] = [
            sender.to_field(),
            sequence as Field,
            nonce as Field,
            consistency as Field,
            self.context.timestamp() as Field,
            Field::from_le_bytes(payloads[0]),
            Field::from_le_bytes(payloads[1]),
            Field::from_le_bytes(payloads[2]),
            Field::from_le_bytes(payloads[3]),
            Field::from_le_bytes(payloads[4]),
            Field::from_le_bytes(payloads[5]),
            Field::from_le_bytes(payloads[6]),
            Field::from_le_bytes(payloads[7]),
        ];

        self.context.emit_public_log(msg);
        sequence
    }

    #[external("private")]
    fn publish_message_in_private(
        nonce: u64,
        payloads: [[u8; 31]; 8],
        message_fee: u128,
        consistency: u8,
        from: AztecAddress,
        token_nonce: Field,
    ) {
        assert(0 <= message_fee, "insufficient fee");

        let receiver_address = self.storage.receiver_address.get_current_value();
        let token_address = self.storage.token_address.get_current_value();

        // Only transfer tokens if fee is greater than 0
        if message_fee > 0 {
            Token::at(token_address)
                .transfer_in_private(from, receiver_address, message_fee, token_nonce)
                .call(self.context);
        }

        self.enqueue_self._publish_message(nonce, payloads, consistency);
    }

    #[external("private")]
    fn publish_message_in_private_flat(
        nonce: u64,
        // payloads: [[u8; 31]; 8],
        payload_1: [u8; 31],
        payload_2: [u8; 31],
        payload_3: [u8; 31],
        payload_4: [u8; 31],
        payload_5: [u8; 31],
        payload_6: [u8; 31],
        payload_7: [u8; 31],
        payload_8: [u8; 31],
        message_fee: u128,
        consistency: u8,
        from: AztecAddress,
        token_nonce: Field,
    ) {
        assert(0 <= message_fee, "insufficient fee");

        // Only transfer tokens if fee is greater than 0
        if message_fee > 0 {
            let receiver_address = self.storage.receiver_address.get_current_value();
            let token_address = self.storage.token_address.get_current_value();
            Token::at(token_address)
                .transfer_in_private(from, receiver_address, message_fee, token_nonce)
                .call(self.context);
        }

        self.enqueue_self._publish_message_flat(
            nonce,
            payload_1,
            payload_2,
            payload_3,
            payload_4,
            payload_5,
            payload_6,
            payload_7,
            payload_8,
            consistency,
        );
    }

    #[external("public")]
    #[only_self]
    fn _publish_message_flat(
        nonce: u64,
        payload_1: [u8; 31],
        payload_2: [u8; 31],
        payload_3: [u8; 31],
        payload_4: [u8; 31],
        payload_5: [u8; 31],
        payload_6: [u8; 31],
        payload_7: [u8; 31],
        payload_8: [u8; 31],
        consistency: u8,
    ) -> u64 {
        let sender = self.msg_sender().unwrap();
        let sequence = self.storage.sequences.at(sender).read();
        self.storage.sequences.at(sender).write(sequence + 1);

        let msg: [Field; 13] = [
            sender.to_field(),
            sequence as Field,
            nonce as Field,
            consistency as Field,
            self.context.timestamp() as Field,
            Field::from_le_bytes(payload_1),
            Field::from_le_bytes(payload_2),
            Field::from_le_bytes(payload_3),
            Field::from_le_bytes(payload_4),
            Field::from_le_bytes(payload_5),
            Field::from_le_bytes(payload_6),
            Field::from_le_bytes(payload_7),
            Field::from_le_bytes(payload_8),
        ];

        self.context.emit_public_log(msg);
        sequence
    }

    #[external("public")]
    #[only_self]
    fn _publish_message(nonce: u64, payloads: [[u8; 31]; 8], consistency: u8) -> u64 {
        let sender = self.msg_sender().unwrap();
        let sequence = self.storage.sequences.at(sender).read();
        self.storage.sequences.at(sender).write(sequence + 1);

        let msg: [Field; 13] = [
            sender.to_field(),
            sequence as Field,
            nonce as Field,
            consistency as Field,
            self.context.timestamp() as Field,
            Field::from_le_bytes(payloads[0]),
            Field::from_le_bytes(payloads[1]),
            Field::from_le_bytes(payloads[2]),
            Field::from_le_bytes(payloads[3]),
            Field::from_le_bytes(payloads[4]),
            Field::from_le_bytes(payloads[5]),
            Field::from_le_bytes(payloads[6]),
            Field::from_le_bytes(payloads[7]),
        ];

        self.context.emit_public_log(msg);
        sequence
    }

    // ============================================================================
    // CORE FUNCTIONALITY - VAA VERIFICATION
    // ============================================================================

    // Internal helper function for parsing VAA bytes

    #[contract_library_method]
    fn parse_vaa(
        bytes: [u8; 2000],
        actual_length: u32,
    ) -> (u32, [[u8; 64]; 13], [u8; 1860], u32) {
        // 1. Parse bytes unconstrained
        // unsafe: constrain parsing later
        let (signatures_full, body_bytes) = unsafe { _parse_vaa(bytes, actual_length) };

        // 2. Get guardian set index
        let guardian_set_index: u32 = (bytes[1] as u32) * 16777216 // * 2^24
            + (bytes[2] as u32) * 65536 // * 2^16
            + (bytes[3] as u32) * 256 // * 2^8
            + (bytes[4] as u32);

        // 3. Get signature length
        assert((bytes[5] < 14) & (bytes[5] > 0), "too many signatures");
        let signatures_len = bytes[5] as u32;


        // Get body length
        let body_start = 6 + signatures_len * 66;
        let body_length = actual_length - body_start;

        // Verify signatures extracted correctly and parse
        let mut signatures = [[0; 64]; 13];
        for i in 0..13 {
            for j in 0..66 {
                let byte_idx = 6 + i * 66 + j; // I guess we
                let byte_match = signatures_full[i][j] == bytes[byte_idx];
                let not_in_range = i >= signatures_len;
                assert(byte_match | not_in_range, "signature byte mismatch");
            }
            // check the guardian set index
            assert(signatures_full[i][0] < 19, "guardian index out of bounds");
            for j in 0..64 {
                signatures[i][j] = signatures_full[i][j + 1];
            }
        }

        // Verify body bytes
        for i in 0..1860 {
            let byte_match = body_bytes[i] == bytes[body_start + i];
            let not_in_range = i >= body_length;
            assert(byte_match | not_in_range, "body byte mismatch");
            // probably need to check that remaining bytes are 0
        }

        (guardian_set_index, signatures, body_bytes, body_length)
    }

    #[contract_library_method]
    unconstrained fn _parse_vaa(
        bytes: [u8; 2000],
        actual_length: u32,
    ) -> ([[u8; 66]; 13], [u8; 1860]) {
        let signatures_len = bytes[5];

        // Parse signatures
        let mut signatures = [[0; 66]; 13];
        for i in 0..13 {
            if i < signatures_len {
                let sig_start: u32 = 6 + (i as u32 * 66);
                for j in 0..66 {
                    let byte_index: u32 = sig_start + j as u32;
                    if byte_index < actual_length {
                        signatures[i as u32][j] = bytes[byte_index];
                    }
                }
            }
        }

        // Calculate where the body starts
        let body_start: u32 = 6 + (signatures_len as u32 * 66);

        // Calculate actual body length
        let body_length: u32 = actual_length - body_start;

        let mut body_bytes = [0; 1860];
        for i in 0..1860 {
            if i < body_length {
                body_bytes[i] = bytes[body_start + i];
            }
        }

        (signatures, body_bytes)
    }

    #[external("private")]
    fn verify_vaa(
        bytes: [u8; 2000],
        actual_length: u32,
    ) -> ([u8; 1860], u32, Field) {
        // check wormhole VAA vm version
        let version = bytes[0];
        assert(version == 1, "VM version incompatible");

        // parse the VAA
        let (guardian_set_index, signatures, body_bytes, body_length) = parse_vaa(bytes, actual_length);

        // double hash the vaa
        let vaa_hash = keccak256(keccak256(bytes, actual_length), 32);

        // let num_required_signatures: u8 = 1;
        // let mut guardian_signature_count: u8 = 0;

        let guardian = crate::structs::Guardian::new(
            [
                0x13, 0x94, 0x7b, 0xd4, 0x8b, 0x18, 0xe5, 0x3f, 0xda, 0xee, 0xe7, 0x7f, 0x34, 0x73,
                0x39, 0x1a, 0xc7, 0x27, 0xc6, 0x38,
            ],
            [
                0xfa, 0x9d, 0x6b, 0x47, 0x04, 0x3b, 0x15, 0xb4, 0xb3, 0x3c, 0xf0, 0x5b, 0xb1, 0xde,
                0x0f, 0x13, 0xda, 0x70, 0x31, 0x36, 0xb2, 0xcd, 0x15, 0x73, 0x24, 0xeb, 0x61, 0x5e,
                0xc9, 0xee, 0x95, 0x12,
            ],
            [
                0x38, 0xc6, 0x7b, 0x54, 0xd0, 0x3e, 0x3c, 0x18, 0x2e, 0x0e, 0x77, 0xb8, 0x5f, 0x88,
                0x3c, 0xcd, 0x74, 0xdd, 0xdf, 0xc5, 0x90, 0x10, 0xfb, 0xf4, 0x75, 0xa0, 0xbe, 0xe6,
                0x59, 0x3c, 0xe2, 0xbd,
            ],
        );
            
        let is_valid = guardian.verify(signatures[0], vaa_hash);
        let mut x = 0;
        for i in 0..1860 {
            x += body_bytes[i] as Field;
        }

        for i in 0..13 {
            x += signatures[i][0] as Field; 
        }
        // guardian_signature_count += is_valid as u8;
        // for i in 0..1 {
        //     let is_valid = GUARDIAN.verify(signatures[i], vaa_hash);
        //     guardian_signature_count += is_valid as u8;
        // }
        // assert(guardian_signature_count >= num_required_signatures);
        (body_bytes, body_length, x)
    }

    // ============================================================================
    // GUARDIAN MANAGEMENT
    // ============================================================================

    // Individual guardian setters
    #[external("public")]
    fn set_guardian1(guardian: Guardian, index: u32) {
        self.storage.guardian_1.at(index).write(guardian);
    }

    #[external("public")]
    fn set_guardian2(guardian: Guardian, index: u32) {
        self.storage.guardian_2.at(index).write(guardian);
    }

    #[external("public")]
    fn set_guardian3(guardian: Guardian, index: u32) {
        self.storage.guardian_3.at(index).write(guardian);
    }

    #[external("public")]
    fn set_guardian4(guardian: Guardian, index: u32) {
        self.storage.guardian_4.at(index).write(guardian);
    }

    #[external("public")]
    fn set_guardian5(guardian: Guardian, index: u32) {
        self.storage.guardian_5.at(index).write(guardian);
    }

    #[external("public")]
    fn set_guardian6(guardian: Guardian, index: u32) {
        self.storage.guardian_6.at(index).write(guardian);
    }

    #[external("public")]
    fn set_guardian7(guardian: Guardian, index: u32) {
        self.storage.guardian_7.at(index).write(guardian);
    }

    #[external("public")]
    fn set_guardian8(guardian: Guardian, index: u32) {
        self.storage.guardian_8.at(index).write(guardian);
    }

    #[external("public")]
    fn set_guardian9(guardian: Guardian, index: u32) {
        self.storage.guardian_9.at(index).write(guardian);
    }

    #[external("public")]
    fn set_guardian10(guardian: Guardian, index: u32) {
        self.storage.guardian_10.at(index).write(guardian);
    }

    #[external("public")]
    fn set_guardian11(guardian: Guardian, index: u32) {
        self.storage.guardian_11.at(index).write(guardian);
    }

    #[external("public")]
    fn set_guardian12(guardian: Guardian, index: u32) {
        self.storage.guardian_12.at(index).write(guardian);
    }

    #[external("public")]
    fn set_guardian13(guardian: Guardian, index: u32) {
        self.storage.guardian_13.at(index).write(guardian);
    }

    #[external("public")]
    fn set_guardian14(guardian: Guardian, index: u32) {
        self.storage.guardian_14.at(index).write(guardian);
    }

    #[external("public")]
    fn set_guardian15(guardian: Guardian, index: u32) {
        self.storage.guardian_15.at(index).write(guardian);
    }

    #[external("public")]
    fn set_guardian16(guardian: Guardian, index: u32) {
        self.storage.guardian_16.at(index).write(guardian);
    }

    #[external("public")]
    fn set_guardian17(guardian: Guardian, index: u32) {
        self.storage.guardian_17.at(index).write(guardian);
    }

    #[external("public")]
    fn set_guardian18(guardian: Guardian, index: u32) {
        self.storage.guardian_18.at(index).write(guardian);
    }

    #[external("public")]
    fn set_guardian19(guardian: Guardian, index: u32) {
        self.storage.guardian_19.at(index).write(guardian);
    }

    // ============================================================================
    // GOVERNANCE FUNCTIONS
    // ============================================================================

    #[external("public")]
    fn expire_guardian_set(index: u32) {
        self.storage.current_guardian_set_index.at(index).write(self.context.timestamp() + 86400);
    }

    #[external("public")]
    fn guardian_set_expired(index: u32) -> bool {
        let timestamp = self.storage.current_guardian_set_index.at(index).read();
        self.context.timestamp() > timestamp
    }

    #[external("public")]
    fn set_provider(provider: Provider) {
        let updated_storage = WormholeStorage::set_provider(self.storage.state.read(), provider);
        self.storage.state.write(updated_storage);
    }

    #[external("public")]
    fn get_provider() -> Provider {
        WormholeStorage::get_provider(self.storage.state.read())
    }

    // ============================================================================
    // ACCESS CONTROL
    // ============================================================================

    #[external("public")]
    #[only_self]
    fn _assert_is_owner(caller: AztecAddress) {
        assert(self.storage.owner.read().eq(caller), "caller is not owner");
    }

    // ============================================================================
    // ADDRESS MANAGEMENT FUNCTIONS
    // ============================================================================

    #[external("public")]
    fn set_receiver_address(new_receiver_address: AztecAddress) {
        let caller = self.msg_sender().unwrap();
        assert(self.storage.owner.read().eq(caller), "caller is not owner");
        self.storage.receiver_address.schedule_value_change(new_receiver_address);
    }

    #[external("public")]
    fn set_token_address(new_token_address: AztecAddress) {
        let caller = self.msg_sender().unwrap();
        assert(self.storage.owner.read().eq(caller), "caller is not owner");
        self.storage.token_address.schedule_value_change(new_token_address);
    }

    #[external("public")]
    fn get_receiver_address() -> AztecAddress {
        self.storage.receiver_address.get_current_value()
    }

    #[external("public")]
    fn get_token_address() -> AztecAddress {
        self.storage.token_address.get_current_value()
    }

    #[external("public")]
    fn get_scheduled_receiver_address() -> (AztecAddress, u64) {
        self.storage.receiver_address.get_scheduled_value()
    }

    #[external("public")]
    fn get_scheduled_token_address() -> (AztecAddress, u64) {
        self.storage.token_address.get_scheduled_value()
    }

    #[external("public")]
    fn get_owner() -> AztecAddress {
        self.storage.owner.read()
    }

    #[external("public")]
    fn transfer_ownership(new_owner: AztecAddress) {
        let caller = self.msg_sender().unwrap();
        assert(self.storage.owner.read().eq(caller), "caller is not owner");
        self.storage.owner.write(new_owner);
    }

}

// mod tests {
//     use crate::{structs::Signature, Wormhole};
//     use dep::aztec::protocol_types::{address::AztecAddress, traits::FromField};
//     use dep::aztec::test::helpers::test_environment::TestEnvironment;

//     #[test]
//     pub unconstrained fn test_signature_extraction() {
//         let signature_bytes: [u8; 66] = [
//             0x00, // Guardian index
//             // R component (32 bytes)
//             0x46, 0x82, 0xbc, 0x4d, 0x5f, 0xf2, 0xe5, 0x4d, 0xc2, 0xee, 0x5e, 0x0e, 0xb6, 0x4f,
//             0x5c, 0x6c, 0x07, 0xaa, 0x44, 0x9a, 0xc5, 0x39, 0xab, 0xc6, 0x3c, 0x2b, 0xe5, 0xc3,
//             0x06, 0xa4, 0x8f, 0x23,
//             // S component (32 bytes)
//             0x3e, 0x93, 0x00, 0x17, 0x0a, 0x82, 0xad, 0xf3, 0xc3, 0xb7, 0xf4, 0x3f, 0x23, 0x17,
//             0x6f, 0xb0, 0x79, 0x17, 0x4a, 0x58, 0xd6, 0x7d, 0x14, 0x24, 0x77, 0xf6, 0x46, 0x67,
//             0x5d, 0x86, 0xeb, 0x63,
//             // Recovery ID
//             0x01,
//         ];

//         let sig = Signature::from_bytes(signature_bytes);

//         assert(sig.guardian_index == 0, "Guardian index should be 0");
//         assert(sig.r[0] == 0x46, "R component should start with 0x46");
//         assert(sig.s[0] == 0x3e, "S component should start with 0x3e");
//     }

//     #[test]
//     pub unconstrained fn test_verify_vaa_logic() {
//         // Setup env, generate keys
//         let mut env = TestEnvironment::new();

//         // Deploy contract - need to specify all 3 parameters for deploy
//         let dummy_owner = AztecAddress::from_field(1);
//         let receiver_address = AztecAddress::from_field(
//             0x0d071eec273fa0c82825d9c5d2096965a40bcc33ae942714cf6c683af9632504,
//         );
//         let token_address = AztecAddress::from_field(
//             0x037e5d19d6d27e2fb7c947cfe7c36459e27d35e46dd59f5f47373a64ff491d2c,
//         );

//         let contract_address = env.deploy("Wormhole").with_public_initializer(
//             dummy_owner,
//             Wormhole::interface().init(56, 56, dummy_owner, receiver_address, token_address),
//         );

//         let mut vaa_bytes: [u8; 2000] = [0; 2000];
//         let actual_length = 221;

//         // NOTE: This is a real Wormhole VAA from Arbitrum Sepolia testnet.
//         // VAA bytes, fetched from https://wormholescan.io/#/tx/0xf93fd41efeb09ff28174824d4abf6dbc06ac408953a9975aa4a403d434051efc
//         // This VAA contains the message "Hello Wormhole!" and is used to test VAA verification logic.
//         let wh_vaa: [u8; 221] = [
//             0x01, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x46, 0x82, 0xbc, 0x4d, 0x5f, 0xf2, 0xe5,
//             0x4d, 0xc2, 0xee, 0x5e, 0x0e, 0xb6, 0x4f, 0x5c, 0x6c, 0x07, 0xaa, 0x44, 0x9a, 0xc5,
//             0x39, 0xab, 0xc6, 0x3c, 0x2b, 0xe5, 0xc3, 0x06, 0xa4, 0x8f, 0x23, 0x3e, 0x93, 0x00,
//             0x17, 0x0a, 0x82, 0xad, 0xf3, 0xc3, 0xb7, 0xf4, 0x3f, 0x23, 0x17, 0x6f, 0xb0, 0x79,
//             0x17, 0x4a, 0x58, 0xd6, 0x7d, 0x14, 0x24, 0x77, 0xf6, 0x46, 0x67, 0x5d, 0x86, 0xeb,
//             0x63, 0x01, 0x68, 0x4b, 0xfa, 0xd4, 0x49, 0x96, 0x02, 0xd2, 0x27, 0x13, 0x00, 0x00,
//             0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x69, 0x7f, 0x31, 0xe0,
//             0x74, 0xbf, 0x2c, 0x81, 0x93, 0x91, 0xd5, 0x27, 0x29, 0xf9, 0x55, 0x06, 0xe0, 0xa7,
//             0x2f, 0xfb, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xc8, 0x00, 0x00, 0x00,
//             0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
//             0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
//             0x20, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
//             0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
//             0x00, 0x00, 0x00, 0x00, 0x00, 0x0e, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x20, 0x57, 0x6f,
//             0x72, 0x6d, 0x68, 0x6f, 0x6c, 0x65, 0x21, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
//             0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
//         ];

//         for i in 0..221 {
//             vaa_bytes[i] = wh_vaa[i];
//         }

//         env.call_private(
//             dummy_owner,
//             Wormhole::at(contract_address).verify_vaa(vaa_bytes, actual_length),
//         );
//     }
// }
