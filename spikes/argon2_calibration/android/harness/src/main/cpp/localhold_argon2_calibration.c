// SPDX-License-Identifier: MPL-2.0
#include <jni.h>
#include <sodium.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define LOCALHOLD_OUTPUT_BYTES 32U
#define LOCALHOLD_HASH_BYTES crypto_hash_sha256_BYTES
#define LOCALHOLD_SALT_BYTES crypto_pwhash_SALTBYTES
#define LOCALHOLD_MAX_PASSWORD_BYTES 1024
#define LOCALHOLD_MAX_SAMPLES 50

static int is_allowed_memory_kib(const jint memory_kib) {
    return memory_kib == 65536 || memory_kib == 98304 || memory_kib == 131072;
}

static int is_allowed_operations(const jlong operations) {
    return operations == 2 || operations == 3 || operations == 4;
}

static uint64_t elapsed_nanoseconds(const struct timespec *start, const struct timespec *end) {
    const int64_t seconds = (int64_t) end->tv_sec - (int64_t) start->tv_sec;
    const int64_t nanoseconds = (int64_t) end->tv_nsec - (int64_t) start->tv_nsec;
    return (uint64_t) (seconds * INT64_C(1000000000) + nanoseconds);
}

static void hex_encode(const unsigned char *input, const size_t input_length, char *output) {
    static const char hex[] = "0123456789abcdef";
    for (size_t index = 0; index < input_length; index++) {
        output[index * 2] = hex[input[index] >> 4];
        output[index * 2 + 1] = hex[input[index] & 0x0f];
    }
    output[input_length * 2] = '\0';
}

static jstring error_json(JNIEnv *env, const char *code) {
    char buffer[96];
    const int written = snprintf(buffer, sizeof(buffer), "{\"ok\":false,\"error\":\"%s\"}", code);
    if (written < 0 || (size_t) written >= sizeof(buffer)) {
        return (*env)->NewStringUTF(env, "{\"ok\":false,\"error\":\"internalFailure\"}");
    }
    return (*env)->NewStringUTF(env, buffer);
}

JNIEXPORT jstring JNICALL
Java_dev_localhold_argon2_calibration_NativeArgon2Calibration_runSynthetic(
        JNIEnv *env,
        jobject instance,
        jbyteArray password_array,
        jbyteArray salt_array,
        jint memory_kib,
        jlong operations,
        jint samples) {
    (void) instance;
    if (password_array == NULL || salt_array == NULL || !is_allowed_memory_kib(memory_kib) ||
        !is_allowed_operations(operations) || samples < 1 || samples > LOCALHOLD_MAX_SAMPLES) {
        return error_json(env, "invalidRequest");
    }

    const jsize password_length = (*env)->GetArrayLength(env, password_array);
    const jsize salt_length = (*env)->GetArrayLength(env, salt_array);
    if (password_length < 1 || password_length > LOCALHOLD_MAX_PASSWORD_BYTES ||
        salt_length != LOCALHOLD_SALT_BYTES) {
        return error_json(env, "invalidRequest");
    }
    if (sodium_init() < 0) {
        return error_json(env, "platformUnavailable");
    }

    unsigned char *password = sodium_malloc((size_t) password_length);
    unsigned char *salt = sodium_malloc(LOCALHOLD_SALT_BYTES);
    unsigned char *output = sodium_malloc(LOCALHOLD_OUTPUT_BYTES);
    if (password == NULL || salt == NULL || output == NULL) {
        if (password != NULL) sodium_free(password);
        if (salt != NULL) sodium_free(salt);
        if (output != NULL) sodium_free(output);
        return error_json(env, "allocationFailure");
    }

    (*env)->GetByteArrayRegion(env, password_array, 0, password_length, (jbyte *) password);
    (*env)->GetByteArrayRegion(env, salt_array, 0, salt_length, (jbyte *) salt);
    if ((*env)->ExceptionCheck(env)) {
        (*env)->ExceptionClear(env);
        sodium_free(password);
        sodium_free(salt);
        sodium_free(output);
        return error_json(env, "invalidRequest");
    }

    uint64_t durations[LOCALHOLD_MAX_SAMPLES] = {0};
    unsigned char output_hash[LOCALHOLD_HASH_BYTES] = {0};
    int result = 0;
    for (jint index = 0; index < samples; index++) {
        struct timespec start = {0};
        struct timespec end = {0};
        if (clock_gettime(CLOCK_MONOTONIC, &start) != 0) {
            result = -2;
            break;
        }
        result = crypto_pwhash(
                output,
                LOCALHOLD_OUTPUT_BYTES,
                (const char *) password,
                (unsigned long long) password_length,
                salt,
                (unsigned long long) operations,
                (size_t) memory_kib * 1024U,
                crypto_pwhash_ALG_ARGON2ID13);
        if (clock_gettime(CLOCK_MONOTONIC, &end) != 0) {
            result = -2;
            break;
        }
        if (result != 0) {
            break;
        }
        durations[index] = elapsed_nanoseconds(&start, &end);
    }
    if (result == 0) {
        result = crypto_hash_sha256(output_hash, output, LOCALHOLD_OUTPUT_BYTES);
    }

    sodium_memzero(password, (size_t) password_length);
    sodium_memzero(salt, LOCALHOLD_SALT_BYTES);
    sodium_memzero(output, LOCALHOLD_OUTPUT_BYTES);
    sodium_free(password);
    sodium_free(salt);
    sodium_free(output);

    if (result != 0) {
        sodium_memzero(output_hash, sizeof(output_hash));
        return error_json(env, result == -2 ? "clockFailure" : "allocationFailure");
    }

    char hash_hex[LOCALHOLD_HASH_BYTES * 2 + 1];
    hex_encode(output_hash, sizeof(output_hash), hash_hex);
    sodium_memzero(output_hash, sizeof(output_hash));

    const size_t capacity = 256U + (size_t) samples * 24U;
    char *json = calloc(capacity, 1U);
    if (json == NULL) {
        sodium_memzero(hash_hex, sizeof(hash_hex));
        return error_json(env, "allocationFailure");
    }
    int offset = snprintf(
            json,
            capacity,
            "{\"ok\":true,\"algorithm\":\"argon2id\",\"version\":19,\"memory_kib\":%d,\"operations\":%lld,\"parallelism\":1,\"output_sha256\":\"%s\",\"samples_ns\":[",
            memory_kib,
            (long long) operations,
            hash_hex);
    sodium_memzero(hash_hex, sizeof(hash_hex));
    if (offset < 0 || (size_t) offset >= capacity) {
        free(json);
        return error_json(env, "internalFailure");
    }
    for (jint index = 0; index < samples; index++) {
        const int appended = snprintf(
                json + offset,
                capacity - (size_t) offset,
                index == 0 ? "%llu" : ",%llu",
                (unsigned long long) durations[index]);
        if (appended < 0 || (size_t) appended >= capacity - (size_t) offset) {
            sodium_memzero(json, capacity);
            free(json);
            return error_json(env, "internalFailure");
        }
        offset += appended;
    }
    if ((size_t) offset + 3U >= capacity) {
        sodium_memzero(json, capacity);
        free(json);
        return error_json(env, "internalFailure");
    }
    memcpy(json + offset, "]}", 3U);
    const jstring response = (*env)->NewStringUTF(env, json);
    sodium_memzero(json, capacity);
    free(json);
    return response;
}
