package com.frozenfractal.papageno.tools
import mu.KotlinLogging
import java.io.File
import java.net.URL
import java.nio.file.Files
import java.nio.file.StandardCopyOption

/**
 * A read-through cache for http(s) requests.
 */
class WebCache(type: String) {
    private val rootDirectory = Files.createDirectories(File("cache/$type").toPath()).toFile()

    fun get(url: String, cacheKey: String, cacheKeyLength: Int): ByteArray {
        if (cacheKey.length > cacheKeyLength) {
            throw IllegalArgumentException("Cache key $cacheKey is longer than maximum length $cacheKeyLength")
        }

        val fileName = cacheKey.padStart(cacheKeyLength, '_').chunked(2).joinToString("/", transform = this::escapeForFilesystem)
        val file = File(rootDirectory, fileName)

        if (!file.exists()) {
            val tempFile = File(file.path + ".tmp")
            Files.createDirectories(tempFile.parentFile.toPath())

            try {
                fetch(url, tempFile)
                Files.move(tempFile.toPath(), file.toPath(), StandardCopyOption.ATOMIC_MOVE)
                tempFile.renameTo(file)
            } finally {
                tempFile.delete() // Returns false if already gone, does not throw in that case.
            }
        }

        return file.readBytes()
    }

    private fun fetch(url: String, output: File) {
        logger.info { "Fetching $url" }
        URL(url).openConnection().getInputStream().use { response ->
            Files.copy(response, output.toPath(), StandardCopyOption.REPLACE_EXISTING)
        }
    }

    private fun escapeForFilesystem(s: String) =
        s.replace("%", "%25").replace("/", "%2F").replace("\\", "%5C")
}

private val logger = KotlinLogging.logger {}