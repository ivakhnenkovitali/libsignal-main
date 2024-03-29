//
// Copyright 2020 Signal Messenger, LLC.
// SPDX-License-Identifier: AGPL-3.0-only
//

import XCTest
import LibSignalClient

class PublicAPITests: TestCaseBase {
    func testHkdfSimple() {
        let ikm: [UInt8] = [
            0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b,
            0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b, 0x0b,
        ]
        let info: [UInt8] = []
        let salt: [UInt8] = []
        let okm: [UInt8] = [0x8d, 0xa4, 0xe7, 0x75]

        let derived = try! hkdf(outputLength: okm.count,
                                inputKeyMaterial: ikm,
                                salt: salt,
                                info: info)
        XCTAssertEqual(derived, okm)
    }

    func testHkdfUsingRFCExample() {
        // https://tools.ietf.org/html/rfc5869 A.2
        let ikm: [UInt8] = Array(0...0x4f)
        let salt: [UInt8] = Array(0x60...0xaf)
        let info: [UInt8] = Array(0xb0...0xff)
        let okm: [UInt8] = [0xb1, 0x1e, 0x39, 0x8d, 0xc8, 0x03, 0x27, 0xa1, 0xc8, 0xe7, 0xf7, 0x8c, 0x59, 0x6a, 0x49, 0x34,
                            0x4f, 0x01, 0x2e, 0xda, 0x2d, 0x4e, 0xfa, 0xd8, 0xa0, 0x50, 0xcc, 0x4c, 0x19, 0xaf, 0xa9, 0x7c,
                            0x59, 0x04, 0x5a, 0x99, 0xca, 0xc7, 0x82, 0x72, 0x71, 0xcb, 0x41, 0xc6, 0x5e, 0x59, 0x0e, 0x09,
                            0xda, 0x32, 0x75, 0x60, 0x0c, 0x2f, 0x09, 0xb8, 0x36, 0x77, 0x93, 0xa9, 0xac, 0xa3, 0xdb, 0x71,
                            0xcc, 0x30, 0xc5, 0x81, 0x79, 0xec, 0x3e, 0x87, 0xc1, 0x4c, 0x01, 0xd5, 0xc1, 0xf3, 0x43, 0x4f,
                            0x1d, 0x87]

        let derived = try! hkdf(outputLength: okm.count,
                                inputKeyMaterial: ikm,
                                salt: salt,
                                info: info)
        XCTAssertEqual(derived, okm)
    }

    func testAddress() {
        let addr = try! ProtocolAddress(name: "addr1", deviceId: 5)
        XCTAssertEqual(addr.name, "addr1")
        XCTAssertEqual(addr.deviceId, 5)
    }

    func testAddressRoundTripServiceId() {
        let uuid = UUID()
        let aci = Aci(fromUUID: uuid)
        let pni = Pni(fromUUID: uuid)

        let aciAddr = ProtocolAddress(aci, deviceId: 1)
        let pniAddr = ProtocolAddress(pni, deviceId: 1)
        XCTAssertNotEqual(aciAddr, pniAddr)
        XCTAssertEqual(aci, aciAddr.serviceId)
        XCTAssertEqual(pni, pniAddr.serviceId)
    }

    func testPkOperations() {
        let sk = PrivateKey.generate()
        let sk_bytes = sk.serialize()

        let pk = sk.publicKey
        let pk_bytes = pk.serialize()
        XCTAssertEqual(pk_bytes[0], 0x05) // DJB
        XCTAssertEqual(pk_bytes.count, 33)

        let pk_raw = pk.keyBytes
        XCTAssertEqual(pk_raw.count, 32)
        XCTAssertEqual(pk_raw[0...31], pk_bytes[1...32])

        let sk_reloaded = try! PrivateKey(sk_bytes)
        let pk_reloaded = sk_reloaded.publicKey

        XCTAssertEqual(pk, pk_reloaded)

        XCTAssertEqual(pk.serialize(), pk_reloaded.serialize())

        var message: [UInt8] = [1, 2, 3]
        var signature = sk.generateSignature(message: message)

        XCTAssertEqual(try! pk.verifySignature(message: message, signature: signature), true)

        signature[5] ^= 1
        XCTAssertEqual(try! pk.verifySignature(message: message, signature: signature), false)
        signature[5] ^= 1
        XCTAssertEqual(try! pk.verifySignature(message: message, signature: signature), true)
        message[1] ^= 1
        XCTAssertEqual(try! pk.verifySignature(message: message, signature: signature), false)
        message[1] ^= 1
        XCTAssertEqual(try! pk.verifySignature(message: message, signature: signature), true)

        let sk2 = PrivateKey.generate()

        let shared_secret1 = sk.keyAgreement(with: sk2.publicKey)
        let shared_secret2 = sk2.keyAgreement(with: sk.publicKey)

        XCTAssertEqual(shared_secret1, shared_secret2)
    }

    func testFingerprint() {

        let ALICE_IDENTITY: [UInt8] = [0x05, 0x06, 0x86, 0x3b, 0xc6, 0x6d, 0x02, 0xb4, 0x0d, 0x27, 0xb8, 0xd4, 0x9c, 0xa7, 0xc0, 0x9e, 0x92, 0x39, 0x23, 0x6f, 0x9d, 0x7d, 0x25, 0xd6, 0xfc, 0xca, 0x5c, 0xe1, 0x3c, 0x70, 0x64, 0xd8, 0x68]
        let BOB_IDENTITY: [UInt8] = [0x05, 0xf7, 0x81, 0xb6, 0xfb, 0x32, 0xfe, 0xd9, 0xba, 0x1c, 0xf2, 0xde, 0x97, 0x8d, 0x4d, 0x5d, 0xa2, 0x8d, 0xc3, 0x40, 0x46, 0xae, 0x81, 0x44, 0x02, 0xb5, 0xc0, 0xdb, 0xd9, 0x6f, 0xda, 0x90, 0x7b]

        let VERSION_1                      = 1
        let DISPLAYABLE_FINGERPRINT_V1     = "300354477692869396892869876765458257569162576843440918079131"
        let ALICE_SCANNABLE_FINGERPRINT_V1: [UInt8] = [0x08, 0x01, 0x12, 0x22, 0x0a, 0x20, 0x1e, 0x30, 0x1a, 0x03, 0x53, 0xdc, 0xe3, 0xdb, 0xe7, 0x68, 0x4c, 0xb8, 0x33, 0x6e, 0x85, 0x13, 0x6c, 0xdc, 0x0e, 0xe9, 0x62, 0x19, 0x49, 0x4a, 0xda, 0x30, 0x5d, 0x62, 0xa7, 0xbd, 0x61, 0xdf, 0x1a, 0x22, 0x0a, 0x20, 0xd6, 0x2c, 0xbf, 0x73, 0xa1, 0x15, 0x92, 0x01, 0x5b, 0x6b, 0x9f, 0x16, 0x82, 0xac, 0x30, 0x6f, 0xea, 0x3a, 0xaf, 0x38, 0x85, 0xb8, 0x4d, 0x12, 0xbc, 0xa6, 0x31, 0xe9, 0xd4, 0xfb, 0x3a, 0x4d]
        let BOB_SCANNABLE_FINGERPRINT_V1: [UInt8] = [0x08, 0x01, 0x12, 0x22, 0x0a, 0x20, 0xd6, 0x2c, 0xbf, 0x73, 0xa1, 0x15, 0x92, 0x01, 0x5b, 0x6b, 0x9f, 0x16, 0x82, 0xac, 0x30, 0x6f, 0xea, 0x3a, 0xaf, 0x38, 0x85, 0xb8, 0x4d, 0x12, 0xbc, 0xa6, 0x31, 0xe9, 0xd4, 0xfb, 0x3a, 0x4d, 0x1a, 0x22, 0x0a, 0x20, 0x1e, 0x30, 0x1a, 0x03, 0x53, 0xdc, 0xe3, 0xdb, 0xe7, 0x68, 0x4c, 0xb8, 0x33, 0x6e, 0x85, 0x13, 0x6c, 0xdc, 0x0e, 0xe9, 0x62, 0x19, 0x49, 0x4a, 0xda, 0x30, 0x5d, 0x62, 0xa7, 0xbd, 0x61, 0xdf]

        let VERSION_2                      = 2
        let DISPLAYABLE_FINGERPRINT_V2     = DISPLAYABLE_FINGERPRINT_V1
        let ALICE_SCANNABLE_FINGERPRINT_V2: [UInt8] = [0x08, 0x02, 0x12, 0x22, 0x0a, 0x20, 0x1e, 0x30, 0x1a, 0x03, 0x53, 0xdc, 0xe3, 0xdb, 0xe7, 0x68, 0x4c, 0xb8, 0x33, 0x6e, 0x85, 0x13, 0x6c, 0xdc, 0x0e, 0xe9, 0x62, 0x19, 0x49, 0x4a, 0xda, 0x30, 0x5d, 0x62, 0xa7, 0xbd, 0x61, 0xdf, 0x1a, 0x22, 0x0a, 0x20, 0xd6, 0x2c, 0xbf, 0x73, 0xa1, 0x15, 0x92, 0x01, 0x5b, 0x6b, 0x9f, 0x16, 0x82, 0xac, 0x30, 0x6f, 0xea, 0x3a, 0xaf, 0x38, 0x85, 0xb8, 0x4d, 0x12, 0xbc, 0xa6, 0x31, 0xe9, 0xd4, 0xfb, 0x3a, 0x4d]
        let BOB_SCANNABLE_FINGERPRINT_V2: [UInt8] = [0x08, 0x02, 0x12, 0x22, 0x0a, 0x20, 0xd6, 0x2c, 0xbf, 0x73, 0xa1, 0x15, 0x92, 0x01, 0x5b, 0x6b, 0x9f, 0x16, 0x82, 0xac, 0x30, 0x6f, 0xea, 0x3a, 0xaf, 0x38, 0x85, 0xb8, 0x4d, 0x12, 0xbc, 0xa6, 0x31, 0xe9, 0xd4, 0xfb, 0x3a, 0x4d, 0x1a, 0x22, 0x0a, 0x20, 0x1e, 0x30, 0x1a, 0x03, 0x53, 0xdc, 0xe3, 0xdb, 0xe7, 0x68, 0x4c, 0xb8, 0x33, 0x6e, 0x85, 0x13, 0x6c, 0xdc, 0x0e, 0xe9, 0x62, 0x19, 0x49, 0x4a, 0xda, 0x30, 0x5d, 0x62, 0xa7, 0xbd, 0x61, 0xdf]

        // testVectorsVersion1
        let aliceStableId: [UInt8] = [UInt8]("+14152222222".utf8)
        let bobStableId: [UInt8] = [UInt8]("+14153333333".utf8)

        let aliceIdentityKey = try! PublicKey(ALICE_IDENTITY)
        let bobIdentityKey = try! PublicKey(BOB_IDENTITY)

        let generator = NumericFingerprintGenerator(iterations: 5200)

        let aliceFingerprint = try! generator.create(version: VERSION_1,
                                                     localIdentifier: aliceStableId,
                                                     localKey: aliceIdentityKey,
                                                     remoteIdentifier: bobStableId,
                                                     remoteKey: bobIdentityKey)

        let bobFingerprint = try! generator.create(version: VERSION_1,
                                                   localIdentifier: bobStableId,
                                                   localKey: bobIdentityKey,
                                                   remoteIdentifier: aliceStableId,
                                                   remoteKey: aliceIdentityKey)

        XCTAssertEqual(aliceFingerprint.displayable.formatted, DISPLAYABLE_FINGERPRINT_V1)
        XCTAssertEqual(bobFingerprint.displayable.formatted, DISPLAYABLE_FINGERPRINT_V1)

        XCTAssertEqual(aliceFingerprint.scannable.encoding, ALICE_SCANNABLE_FINGERPRINT_V1)
        XCTAssertEqual(bobFingerprint.scannable.encoding, BOB_SCANNABLE_FINGERPRINT_V1)

        XCTAssertTrue(try! bobFingerprint.scannable.compare(againstEncoding: aliceFingerprint.scannable.encoding))
        XCTAssertTrue(try! aliceFingerprint.scannable.compare(againstEncoding: bobFingerprint.scannable.encoding))

        // testVectorsVersion2

        let aliceFingerprint2 = try! generator.create(version: VERSION_2,
                                                      localIdentifier: aliceStableId,
                                                      localKey: aliceIdentityKey,
                                                      remoteIdentifier: bobStableId,
                                                      remoteKey: bobIdentityKey)

        let bobFingerprint2 = try! generator.create(version: VERSION_2,
                                                    localIdentifier: bobStableId,
                                                    localKey: bobIdentityKey,
                                                    remoteIdentifier: aliceStableId,
                                                    remoteKey: aliceIdentityKey)

        XCTAssertEqual(aliceFingerprint2.displayable.formatted, DISPLAYABLE_FINGERPRINT_V2)
        XCTAssertEqual(bobFingerprint2.displayable.formatted, DISPLAYABLE_FINGERPRINT_V2)

        XCTAssertEqual(aliceFingerprint2.scannable.encoding, ALICE_SCANNABLE_FINGERPRINT_V2)
        XCTAssertEqual(bobFingerprint2.scannable.encoding, BOB_SCANNABLE_FINGERPRINT_V2)

        XCTAssertTrue(try! bobFingerprint2.scannable.compare(againstEncoding: aliceFingerprint2.scannable.encoding))
        XCTAssertTrue(try! aliceFingerprint2.scannable.compare(againstEncoding: bobFingerprint2.scannable.encoding))

        XCTAssertThrowsError(try bobFingerprint2.scannable.compare(againstEncoding: aliceFingerprint.scannable.encoding))
        XCTAssertThrowsError(try bobFingerprint.scannable.compare(againstEncoding: aliceFingerprint2.scannable.encoding))

        // testMismatchingFingerprints

        let mitmIdentityKey = PrivateKey.generate().publicKey

        let aliceFingerprintM = try! generator.create(version: VERSION_1,
                                                      localIdentifier: aliceStableId,
                                                      localKey: aliceIdentityKey,
                                                      remoteIdentifier: bobStableId,
                                                      remoteKey: mitmIdentityKey)

        let bobFingerprintM = try! generator.create(version: VERSION_1,
                                                    localIdentifier: bobStableId,
                                                    localKey: bobIdentityKey,
                                                    remoteIdentifier: aliceStableId,
                                                    remoteKey: aliceIdentityKey)

        XCTAssertNotEqual(aliceFingerprintM.displayable.formatted,
                          bobFingerprintM.displayable.formatted)

        XCTAssertFalse(try! bobFingerprintM.scannable.compare(againstEncoding: aliceFingerprintM.scannable.encoding))
        XCTAssertFalse(try! aliceFingerprintM.scannable.compare(againstEncoding: bobFingerprintM.scannable.encoding))

        XCTAssertEqual(aliceFingerprintM.displayable.formatted.count, 60)

        // testMismatchingIdentifiers

        let badBobStableId: [UInt8] = [UInt8]("+14153333334".utf8)

        let aliceFingerprintI = try! generator.create(version: VERSION_1,
                                                      localIdentifier: aliceStableId,
                                                      localKey: aliceIdentityKey,
                                                      remoteIdentifier: badBobStableId,
                                                      remoteKey: bobIdentityKey)

        let bobFingerprintI = try! generator.create(version: VERSION_1,
                                                    localIdentifier: bobStableId,
                                                    localKey: bobIdentityKey,
                                                    remoteIdentifier: aliceStableId,
                                                    remoteKey: aliceIdentityKey)

        XCTAssertNotEqual(aliceFingerprintI.displayable.formatted,
                          bobFingerprintI.displayable.formatted)

        XCTAssertFalse(try! bobFingerprintI.scannable.compare(againstEncoding: aliceFingerprintI.scannable.encoding))
        XCTAssertFalse(try! aliceFingerprintI.scannable.compare(againstEncoding: bobFingerprintI.scannable.encoding))

        // Test bad fingerprint
        XCTAssertThrowsError(try aliceFingerprintI.scannable.compare(againstEncoding: []))
    }

    func testGroupCipher() {

        let sender = try! ProtocolAddress(name: "+14159999111", deviceId: 4)
        let distribution_id = UUID(uuidString: "d1d1d1d1-7000-11eb-b32a-33b8a8a487a6")!

        let a_store = InMemorySignalProtocolStore()

        let skdm = try! SenderKeyDistributionMessage(from: sender, distributionId: distribution_id, store: a_store, context: NullContext())

        let skdm_bits = skdm.serialize()

        let skdm_r = try! SenderKeyDistributionMessage(bytes: skdm_bits)

        let a_ctext = try! groupEncrypt([1, 2, 3], from: sender, distributionId: distribution_id, store: a_store, context: NullContext()).serialize()

        let b_store = InMemorySignalProtocolStore()
        try! processSenderKeyDistributionMessage(skdm_r,
                                                 from: sender,
                                                 store: b_store,
                                                 context: NullContext())
        let b_ptext = try! groupDecrypt(a_ctext, from: sender, store: b_store, context: NullContext())

        XCTAssertEqual(b_ptext, [1, 2, 3])
    }

    func testGroupCipherWithContext() {
        class ContextUsingStore: InMemorySignalProtocolStore {
            var expectedContext: StoreContext & AnyObject

            init(expectedContext: StoreContext & AnyObject) {
                self.expectedContext = expectedContext
                super.init()
            }

            override func loadSenderKey(from sender: ProtocolAddress, distributionId: UUID, context: StoreContext) throws -> SenderKeyRecord? {
                XCTAssertIdentical(expectedContext, context as AnyObject)
                return try super.loadSenderKey(from: sender, distributionId: distributionId, context: context)
            }
        }

        class ContextWithIdentity: StoreContext {}

        let sender = try! ProtocolAddress(name: "+14159999111", deviceId: 4)
        let distribution_id = UUID(uuidString: "d1d1d1d1-7000-11eb-b32a-33b8a8a487a6")!

        let a_store = ContextUsingStore(expectedContext: ContextWithIdentity())

        let skdm = try! SenderKeyDistributionMessage(from: sender, distributionId: distribution_id, store: a_store, context: a_store.expectedContext)

        let skdm_bits = skdm.serialize()

        _ = try! SenderKeyDistributionMessage(bytes: skdm_bits)

        _ = try! groupEncrypt([1, 2, 3], from: sender, distributionId: distribution_id, store: a_store, context: a_store.expectedContext).serialize()
    }

    func testSenderCertificates() {
        let senderCertBits: [UInt8] = [
            0x0a, 0xcd, 0x01, 0x0a, 0x0c, 0x2b, 0x31, 0x34, 0x31, 0x35, 0x32, 0x32, 0x32, 0x32, 0x32, 0x32, 0x32, 0x10, 0x2a, 0x19,
            0x2d, 0x63, 0xb5, 0x5f, 0x00, 0x00, 0x00, 0x00, 0x22, 0x21, 0x05, 0xbb, 0x25, 0x64, 0x9c, 0x79, 0x4b, 0xb4, 0x6c, 0x8c,
            0x57, 0x97, 0x69, 0x3c, 0xc8, 0x05, 0xb1, 0xb8, 0x46, 0xda, 0x91, 0x17, 0x6f, 0xec, 0x6a, 0x3e, 0xf2, 0x1f, 0x41, 0x0b,
            0xe9, 0x60, 0x43, 0x2a, 0x69, 0x0a, 0x25, 0x08, 0x01, 0x12, 0x21, 0x05, 0x4f, 0xbf, 0xfa, 0x55, 0xeb, 0xd5, 0x23, 0xd2,
            0x55, 0x16, 0x96, 0x0c, 0xed, 0x28, 0x99, 0xf2, 0x6a, 0x72, 0xfe, 0x26, 0xd0, 0xe0, 0x2a, 0x9d, 0xae, 0x81, 0x67, 0x1f,
            0x46, 0x5b, 0xa1, 0x1d, 0x12, 0x40, 0x7a, 0xbf, 0xdb, 0x83, 0x6c, 0x15, 0xcb, 0x3a, 0x8c, 0x61, 0x76, 0xb3, 0x30, 0x70,
            0xdf, 0xbc, 0x47, 0xea, 0x4a, 0x90, 0x52, 0x35, 0x3a, 0xc4, 0x2f, 0xb8, 0x7e, 0x4e, 0x4d, 0x33, 0x4f, 0x69, 0xa5, 0xe0,
            0xd4, 0xab, 0xd2, 0xdd, 0x81, 0x9f, 0x61, 0xa2, 0xc0, 0x2a, 0x51, 0xc2, 0x74, 0x51, 0xc9, 0x31, 0xaa, 0x85, 0x35, 0xf8,
            0x32, 0x8d, 0x1e, 0xc8, 0xce, 0x7a, 0x2b, 0x9a, 0x9e, 0x01, 0x32, 0x24, 0x39, 0x64, 0x30, 0x36, 0x35, 0x32, 0x61, 0x33,
            0x2d, 0x64, 0x63, 0x63, 0x33, 0x2d, 0x34, 0x64, 0x31, 0x31, 0x2d, 0x39, 0x37, 0x35, 0x66, 0x2d, 0x37, 0x34, 0x64, 0x36,
            0x31, 0x35, 0x39, 0x38, 0x37, 0x33, 0x33, 0x66, 0x12, 0x40, 0x06, 0x8b, 0xf0, 0xc5, 0xe8, 0x99, 0x83, 0x81, 0x28, 0xbd,
            0x36, 0xd9, 0x2b, 0x01, 0xec, 0xa9, 0x95, 0x9d, 0x00, 0xf2, 0xdb, 0x0b, 0xcb, 0xb6, 0x8b, 0x2a, 0x62, 0xd4, 0xdf, 0x46,
            0xdb, 0xb4, 0x50, 0x14, 0x9e, 0x9d, 0xcb, 0xc6, 0xbd, 0xdb, 0x2b, 0x28, 0x98, 0xfc, 0xd5, 0xff, 0x5c, 0xaf, 0x1b, 0x8c,
            0xf7, 0x2b, 0x36, 0xff, 0xfe, 0x2f, 0x55, 0xf3, 0xec, 0xeb, 0xab, 0x25, 0x47, 0x88]

        let senderCert = try! SenderCertificate(senderCertBits)

        XCTAssertEqual(senderCert.serialize(), senderCertBits)
        XCTAssertEqual(senderCert.expiration, 1605722925)

        XCTAssertEqual(senderCert.deviceId, 42)

        XCTAssertEqual(senderCert.publicKey.serialize().count, 33)

        XCTAssertEqual(senderCert.senderUuid, "9d0652a3-dcc3-4d11-975f-74d61598733f")
        XCTAssertEqual(senderCert.senderAci.serviceIdString, "9d0652a3-dcc3-4d11-975f-74d61598733f")
        XCTAssertEqual(senderCert.senderE164, Optional("+14152222222"))

        let serverCert = senderCert.serverCertificate

        XCTAssertEqual(serverCert.keyId, 1)
        XCTAssertEqual(serverCert.publicKey.serialize().count, 33)
        XCTAssertEqual(serverCert.signatureBytes.count, 64)
    }

    func testSenderCertificateGetSenderAci() {
        let aci = Aci(fromUUID: UUID())
        let trustRoot = IdentityKeyPair.generate()
        let serverKeys = IdentityKeyPair.generate()
        let serverCert = try! ServerCertificate(keyId: 1, publicKey: serverKeys.publicKey, trustRoot: trustRoot.privateKey)
        let senderAddr = try! SealedSenderAddress(aci: aci, deviceId: 1)
        let senderCert = try! SenderCertificate(sender: senderAddr,
                                                publicKey: IdentityKeyPair.generate().publicKey,
                                                expiration: 31337,
                                                signerCertificate: serverCert,
                                                signerKey: serverKeys.privateKey)

        XCTAssertNil(senderCert.senderE164)
        XCTAssertEqual(aci, senderCert.senderAci)
    }

    private func testRoundTrip<Handle>(_ initial: Handle, serialize: (Handle) -> [UInt8], deserialize: ([UInt8]) throws -> Handle, line: UInt = #line) {
        let bytes = serialize(initial)
        let roundTripBytes = serialize(try! deserialize(bytes))
        XCTAssertEqual(bytes, roundTripBytes, "\(Handle.self) did not round trip correctly", line: line)
    }

    func testSerializationRoundTrip() {
        let keyPair = IdentityKeyPair.generate()
        testRoundTrip(keyPair, serialize: { $0.serialize() }, deserialize: { try .init(bytes: $0) })
        testRoundTrip(keyPair.publicKey, serialize: { $0.serialize() }, deserialize: { try .init($0) })
        testRoundTrip(keyPair.privateKey, serialize: { $0.serialize() }, deserialize: { try .init($0) })
        testRoundTrip(keyPair.identityKey, serialize: { $0.serialize() }, deserialize: { try .init(bytes: $0) })

        let preKeyRecord = try! PreKeyRecord(id: 7, publicKey: keyPair.publicKey, privateKey: keyPair.privateKey)
        testRoundTrip(preKeyRecord, serialize: { $0.serialize() }, deserialize: { try .init(bytes: $0) })

        let signedPreKeyRecord = try! SignedPreKeyRecord(
            id: 77,
            timestamp: 42000,
            privateKey: keyPair.privateKey,
            signature: keyPair.privateKey.generateSignature(message: keyPair.publicKey.serialize())
        )
        testRoundTrip(signedPreKeyRecord, serialize: { $0.serialize() }, deserialize: { try .init(bytes: $0) })
    }

    func testDeviceTransferKey() {
        for keyFormat in KeyFormat.allCases {
            let deviceKey = DeviceTransferKey.generate(formattedAs: keyFormat)

            /*
             Anything encoded in an ASN.1 SEQUENCE starts with 0x30 when encoded
             as DER. (This test could be better.)
             */
            let key = deviceKey.privateKeyMaterial()
            XCTAssert(key.count > 0)
            XCTAssertEqual(key[0], 0x30)

            let cert = deviceKey.generateCertificate("name", 30)
            XCTAssert(cert.count > 0)
            XCTAssertEqual(cert[0], 0x30)
        }
    }

    func testSignAlternateIdentity() {
        let primary = IdentityKeyPair.generate()
        let secondary = IdentityKeyPair.generate()
        let signature = secondary.signAlternateIdentity(primary.identityKey)
        XCTAssert(try! secondary.identityKey.verifyAlternateIdentity(primary.identityKey, signature: signature))
    }
}
