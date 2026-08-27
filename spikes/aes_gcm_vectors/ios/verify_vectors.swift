// SPDX-License-Identifier: MPL-2.0

import CryptoKit
import Foundation

struct Vector {
    let key: String
    let nonce: String
    let aad: String
    let plaintext: String
    let ciphertext: String
    let tag: String
}

extension Data {
    init(hex: String) {
        precondition(hex.count.isMultiple(of: 2))
        self.init()
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            append(UInt8(hex[index..<next], radix: 16)!)
            index = next
        }
    }
}

let vectors = [
    Vector(key: String(repeating: "00", count: 32), nonce: "000102030405060708090a0b", aad: "6c6f63616c686f6c642d616164", plaintext: "", ciphertext: "", tag: "3466421ccd5e61c0a3cda8065e1fe284"),
    Vector(key: "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", nonce: "101112131415161718191a1b", aad: "7b2276223a312c2274797065223a227265636f7264227d", plaintext: "4c6f63616c686f6c642073796e746865746963207265636f7264", ciphertext: "3191fb7725a155dfae557b64610d0136a3392d2e69a734de959d", tag: "894a9c6eec69e231c57fac8bde92b415"),
    Vector(key: String(repeating: "f0", count: 32), nonce: "202122232425262728292a2b", aad: "7661756c743a64656d6f7c7265636f72643a756e69636f6465", plaintext: "d09fd0b0d180d0bed0bbd18c20f09f94902065cc81", ciphertext: "cc888b71b65a58d1ab092d91705220c1938c024985", tag: "70352c437319e1a2c375276ddbdd9561"),
    Vector(key: String(repeating: "a5", count: 32), nonce: "303132333435363738393a3b", aad: "000102ff", plaintext: "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f", ciphertext: "d67fa54dbc7812cd8e15053ce305a386a21e159dfbc15eb120dd1c6fac3dc542011cd2ee29d94bf1afc0a0ea063844a0f771c8d2a4f44642c2dae2f378c13318", tag: "4417641c643e8ac97b886c27bcbcbaca"),
]

for vector in vectors {
    let key = SymmetricKey(data: Data(hex: vector.key))
    let nonce = try AES.GCM.Nonce(data: Data(hex: vector.nonce))
    let plaintext = Data(hex: vector.plaintext)
    let aad = Data(hex: vector.aad)
    let expectedCiphertext = Data(hex: vector.ciphertext)
    let expectedTag = Data(hex: vector.tag)

    let sealed = try AES.GCM.seal(plaintext, using: key, nonce: nonce, authenticating: aad)
    precondition(sealed.ciphertext == expectedCiphertext)
    precondition(sealed.tag == expectedTag)

    let box = try AES.GCM.SealedBox(nonce: nonce, ciphertext: expectedCiphertext, tag: expectedTag)
    let opened = try AES.GCM.open(box, using: key, authenticating: aad)
    precondition(opened == plaintext)

    var tamperedTag = expectedTag
    tamperedTag[0] ^= 1
    do {
        let tampered = try AES.GCM.SealedBox(nonce: nonce, ciphertext: expectedCiphertext, tag: tamperedTag)
        _ = try AES.GCM.open(tampered, using: key, authenticating: aad)
        fatalError("tampered tag authenticated")
    } catch CryptoKitError.authenticationFailure {
        // Required failure.
    }
}

print("Verified \(vectors.count) AES-256-GCM CryptoKit vectors.")
