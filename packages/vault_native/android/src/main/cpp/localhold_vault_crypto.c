// SPDX-License-Identifier: MPL-2.0
#include <jni.h>
#include <sodium.h>
#include <stddef.h>

#define LOCALHOLD_KEK_BYTES 32U
#define LOCALHOLD_SALT_BYTES crypto_pwhash_SALTBYTES
#define LOCALHOLD_MAX_PASSWORD_BYTES 1024

static int allowed_memory(const jint memory_kib) {
    return memory_kib == 65536 || memory_kib == 98304 || memory_kib == 131072;
}

static int allowed_operations(const jlong operations) {
    return operations == 2 || operations == 3 || operations == 4;
}

JNIEXPORT jbyteArray JNICALL
Java_dev_localhold_localhold_1key_1bridge_NativeArgon2_derive(
        JNIEnv *env,
        jobject instance,
        jbyteArray password_array,
        jbyteArray salt_array,
        jint memory_kib,
        jlong operations) {
    (void) instance;
    if (password_array == NULL || salt_array == NULL ||
        !allowed_memory(memory_kib) || !allowed_operations(operations)) {
        return NULL;
    }
    const jsize password_length = (*env)->GetArrayLength(env, password_array);
    const jsize salt_length = (*env)->GetArrayLength(env, salt_array);
    if (password_length < 1 || password_length > LOCALHOLD_MAX_PASSWORD_BYTES ||
        salt_length != LOCALHOLD_SALT_BYTES || sodium_init() < 0) {
        return NULL;
    }

    unsigned char *password = sodium_malloc((size_t) password_length);
    unsigned char *salt = sodium_malloc(LOCALHOLD_SALT_BYTES);
    unsigned char *output = sodium_malloc(LOCALHOLD_KEK_BYTES);
    if (password == NULL || salt == NULL || output == NULL) {
        if (password != NULL) sodium_free(password);
        if (salt != NULL) sodium_free(salt);
        if (output != NULL) sodium_free(output);
        return NULL;
    }

    (*env)->GetByteArrayRegion(env, password_array, 0, password_length,
                              (jbyte *) password);
    (*env)->GetByteArrayRegion(env, salt_array, 0, salt_length, (jbyte *) salt);
    if ((*env)->ExceptionCheck(env)) {
        (*env)->ExceptionClear(env);
        sodium_memzero(password, (size_t) password_length);
        sodium_memzero(salt, LOCALHOLD_SALT_BYTES);
        sodium_memzero(output, LOCALHOLD_KEK_BYTES);
        sodium_free(password);
        sodium_free(salt);
        sodium_free(output);
        return NULL;
    }

    const int result = crypto_pwhash(
            output, LOCALHOLD_KEK_BYTES, (const char *) password,
            (unsigned long long) password_length, salt,
            (unsigned long long) operations, (size_t) memory_kib * 1024U,
            crypto_pwhash_ALG_ARGON2ID13);

    jbyteArray response = NULL;
    if (result == 0) {
        response = (*env)->NewByteArray(env, LOCALHOLD_KEK_BYTES);
        if (response != NULL) {
            (*env)->SetByteArrayRegion(
                    env, response, 0, LOCALHOLD_KEK_BYTES, (const jbyte *) output);
        }
    }
    sodium_memzero(password, (size_t) password_length);
    sodium_memzero(salt, LOCALHOLD_SALT_BYTES);
    sodium_memzero(output, LOCALHOLD_KEK_BYTES);
    sodium_free(password);
    sodium_free(salt);
    sodium_free(output);
    return response;
}
