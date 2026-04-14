package bmi.model;

import java.nio.charset.StandardCharsets;

/**
 * Helper class for converting Java Strings to Fortran-compatible fixed-size byte arrays.
 *
 * Fortran character arrays use kind=c_char (single-byte ASCII) with a fixed length
 * of BMI_MAX_* bytes. Java Strings cannot be passed directly to these functions —
 * doing so causes a SIGSEGV because JNA maps String to char* (variable length)
 * while Fortran expects a fixed 2048-byte buffer.
 *
 * Usage:
 *   library.initialize(handle, new FortranString("config.cfg").toBytes());
 *   library.get_value_float(handle, new FortranString("temperature").toBytes(), dest);
 *   library.initialize(handle, new FortranString("").toBytes()); // use model defaults
 */
public class FortranString {

    /** Required buffer size — Fortran expects EXACTLY this many bytes */
    public static final int BUFFER_SIZE = 2048;

    private final String value;

    public FortranString(String value) {
        this.value = value != null ? value : "";
    }

    /**
     * Convert to a fixed-size byte array suitable for Fortran string parameters.
     *
     * @return byte array of exactly BUFFER_SIZE bytes, null-terminated, US_ASCII encoded
     * @throws IllegalArgumentException if the string is too long for the buffer
     */
    public byte[] toBytes() {
        byte[] buf = new byte[BUFFER_SIZE];
        if (!value.isEmpty()) {
            byte[] bytes = value.getBytes(StandardCharsets.US_ASCII);
            if (bytes.length >= BUFFER_SIZE) {
                throw new IllegalArgumentException(
                    "String too long for Fortran buffer (" + bytes.length
                    + " >= " + BUFFER_SIZE + "): " + value);
            }
            System.arraycopy(bytes, 0, buf, 0, bytes.length);
            // null terminator already present — buf is zero-initialized
        }
        return buf;
    }

    /**
     * Convert a Fortran output byte array back to a Java String.
     * Reads up to the first null terminator.
     *
     * @param bytes  byte array from a Fortran string output parameter
     * @return trimmed Java String, US_ASCII decoded
     */
    public static String fromBytes(byte[] bytes) {
        for (int i = 0; i < bytes.length; i++) {
            if (bytes[i] == 0) {
                return new String(bytes, 0, i, StandardCharsets.US_ASCII);
            }
        }
        throw new IllegalArgumentException(
            "Byte array not null-terminated within " + bytes.length + " bytes");
    }

    @Override
    public String toString() {
        return value;
    }
}
